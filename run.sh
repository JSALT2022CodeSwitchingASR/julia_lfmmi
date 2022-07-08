#!/usr/bin/env bash
set -e

corpus=soapies
corporadir=$PWD/data/$corpus
manifestsdir=$PWD/manifests
lang="xhosa" # leave empty if the corpus is monolingual


#######################################################################
# Download and prepare the data
#######################################################################
if [ ! -z $lang ]; then
    opts="-l $lang"
fi
lhotse download $corpus $opts $corporadir
lhotse prepare $corpus $opts $corporadir $manifestsdir

