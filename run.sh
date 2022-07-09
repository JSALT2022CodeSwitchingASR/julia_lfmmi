#!/usr/bin/env bash

set -eou pipefail

stage=$1
if [ $# -gt 1 ]; then
    echo "usage: $0 [stage]"
    exit 1
fi
[ ! -z $1 ] && stage=$1

corpus=soapies
corporadir=$PWD/data/$corpus
manifestsdir=$PWD/manifests
lang="xhosa" # leave empty if the corpus is monolingual
expdir=exp/$lang
njobs=4

if [ $stage -le 1 ]; then

echo "================================================================"
echo " 1. Download and prepare the data"
echo "================================================================"
lhotse download $corpus -l $lang $corporadir
lhotse prepare $corpus -l $lang $corporadir $manifestsdir

fi

if [ $stage -le 2 ]; then

echo "================================================================"
echo " 2. Download and prepare the lexicon and the phonet set"
echo "================================================================"
python local/prepare_lang.py $lang lang/$lang

fi

if [ $stage -le 3 ]; then

echo "================================================================"
echo " 3. Prepare the configuration files"
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
train_manifest = "manifests/$lang/soapies-${lang}_supervisions_train.jsonl.gz"
dev_manifest = "manifests/$lang/soapies-${lang}_supervisions_dev.jsonl.gz"

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

fi

if [ $stage -le 4 ]; then

echo "================================================================"
echo " 4. Prepare the numerator and denominator graphs"
echo "================================================================"

if [ ! -f $expdir/.graph.completed ]; then
    CONFIG=$expdir/graph_config.toml \
        julia --project=$PWD --procs $njobs scripts/prepare-lfmmi-graphs.jl
    touch $expdir/.graph.completed
else
    echo "numerator/denominator graphs alreay created"
fi

fi

