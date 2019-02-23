#
# JupyterKernel: Jupyter kernel using ZeroMQ
#
# This file runs package tests. It is also referenced in the package
# metadata in PackageInfo.g.
#
LoadPackage( "JupyterKernel" );

TestDirectory( DirectoriesPackageLibrary("JupyterKernel", "tst"),
            rec(exitGAP     := true, 
                exclude     := [ "protocol.tst" ],
                testOptions := rec(compareFunction := "uptowhitespace") ) );

# Should never get here
FORCE_QUIT_GAP(1);
