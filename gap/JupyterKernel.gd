#! @Chapter Jupyter Kernel
#!
#! A <C>Jupyter Kernel</C> is an object that can handles the Jupyter Protocol.
#!
#! @Section Functions
#!

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

#! @Description
#! Opens a file that is used to log all jupyter protocol
#! messages.
#! @Arguments filename
DeclareGlobalFunction( "JUPYTER_LogProtocol" );
#! @Description
#! Closes the protocol log.
DeclareGlobalFunction( "JUPYTER_UnlogProtocol" );

DeclareGlobalFunction( "JUPYTER_KernelStart_HPC" );

# Maybe these two should be one function
DeclareGlobalFunction( "JUPYTER_KernelStart_GAP" );
DeclareGlobalFunction( "JUPYTER_KernelLoop");


DeclareGlobalFunction( "NewJupyterKernel" );
DeclareCategory( "IsJupyterKernel", IsComponentObjectRep );

DeclareRepresentation( "IsGAPJupyterKernel", IsJupyterKernel, [] );
DeclareRepresentation( "IsHPCGAPJupyterKernel", IsJupyterKernel, [] );

BindGlobal( "GAPJupyterKernelType", NewType( NewFamily("JupyterKernelFamily")
                                        , IsGAPJupyterKernel ) );

BindGlobal( "HPCGAPJupyterKernelType", NewType( NewFamily("JupyterKernelFamily")
                                           , IsHPCGAPJupyterKernel ) );

DeclareOperation( "Run", [ IsJupyterKernel ]);
