#
# JupyterKernel: Jupyter kernel using ZeroMQ
#
# Declarations
#

# Default kernel config for experimentation. We'll have to
# find a way to read this into a gap session.
BindGlobal( "JupyterDefaultKernelConfig",
    rec( transport := "tcp"
       , ip := "127.0.0.1"
       , iopub_port   := 5678
       , control_port := 5679
       , shell_port   := 5680
       , stdin_port   := 5681
       , hb_port      := 5682
       , signature_scheme := "hmac-sha256"
       , key := "" )
    );

DeclareGlobalFunction( "JUPYTER_KernelStart_HPC" );

# Maybe these two should be one function
DeclareGlobalFunction( "JUPYTER_KernelStart_GAP" );
DeclareGlobalFunction( "JUPYTER_KernelLoop");
