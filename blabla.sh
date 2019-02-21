#!/bin/sh

set +ex

$GAPROOT/gap <<INPUT
SetInfoLevel(InfoPackageLoading, 4);
LoadPackage("JupyterKernel");
INPUT
