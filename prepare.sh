#!/usr/bin/env bash

#set -eou pipefail

corpus=soapies
manifestsdir=manifests
corporadir=data/$corpus
lang="xhosa"
njobs=$(nproc)
stage=1
stop_stage=100

. utils/parse_options.sh

langdir=lang/$lang
feadir=features/$lang
expdir=exp/$lang

if [ $stage -le 1 ] && [ $stop_stage -ge 1 ]; then

echo "================================================================"
echo " 1. Download and prepare the data"
echo "================================================================"
lhotse download $corpus -l $lang $corporadir
lhotse prepare $corpus -l $lang $corporadir $manifestsdir

fi

if [ $stage -le 2 ] && [ $stop_stage -ge 2 ]; then

echo "================================================================"
echo " 2. Extract features"
echo "================================================================"
mkdir -p $feadir
lhotse feat write-default-config $feadir/fbank.yml
for split in train dev test; do
    if [ ! -f $feadir/$lang/.${split}.completed ]; then
        lhotse feat extract-cuts -j $njobs -f $feadir/fbank.yml \
            $manifestsdir/$lang/${split}_cuts.jsonl.gz \
            $manifestsdir/$lang/${split}_fbank.jsonl.gz \
            $feadir/fbank/${split}
        touch $feadir/$lang/.${split}.completed
    else
        echo "features already extracted for ${split}"
    fi
done

fi

if [ $stage -le 3 ] && [ $stop_stage -ge 3 ]; then

echo "================================================================"
echo " 3. Download and prepare the lexicon and the phonet set"
echo "================================================================"
python local/prepare_lang.py $lang $langdir

fi

if [ $stage -le 4 ] && [ $stop_stage -ge 4 ]; then

echo "================================================================"
echo " 4. Prepare the numerator and denominator graphs"
echo "================================================================"

mkdir -p $expdir

cat > $expdir/hmm_topo.json <<EOF
{
    "semiring": "LogSemiring{Float32}",
    "initstates": [[1, 0]],
    "arcs": [[1, 2, 0], [2, 2, 0]],
    "finalstates": [[2, 0]],
    "labels": [1, 2]
}
EOF
echo "HMM topology: $expdir/hmm_topo.json"

cat > $expdir/graph_config.toml << EOF
[data]
units = "lang/$lang/units"
lexicon = "lang/$lang/lexicon"
train_manifest = "manifests/$lang/train_cuts.jsonl.gz"
dev_manifest = "manifests/$lang/dev_cuts.jsonl.gz"

[supervision]
outdir = "exp/$lang"
silword = "<sil>"
unkword = "<unk>"
initial_silprob = 0.8
silprob = 0.2
final_silprob = 0.8
ngram_order = 3
topo = "$expdir/hmm_topo.json"
EOF
echo "graphs (numerator/denominator) config: $expdir/graph_config.toml"

if [ ! -f $expdir/.graph.completed ]; then
    CONFIG=$expdir/graph_config.toml \
        julia --project=$PWD --procs $njobs scripts/prepare-lfmmi-graphs.jl
    touch $expdir/.graph.completed
else
    echo "numerator/denominator graphs alreay created"
fi

fi

