#!/usr/bin/env bash
set -ex

mkdir $COVDIR
GAP="$GAPROOT/bin/gap.sh --quitonbreak -q"
$GAP --cover $COVDIR/test.coverage tst/testall.g

export JUPYTER_GAP_EXECUTABLE="$PWD/$GAPROOT/bin/gap.sh --quitonbreak --cover $PWD/$COVDIR/testnb.coverage"
jupyter nbconvert tst/test.ipynb --to notebook --execute

