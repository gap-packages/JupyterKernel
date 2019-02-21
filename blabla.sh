#!/bin/sh

set +ex

GAP="$GAPROOT/bin/gap.sh -l $PWD/gaproot; --quitonbreak"

$GAP <<INPUT
SetInfoLevel(InfoPackageLoading, 4);
LoadPackage("JupyterKernel");
INPUT
