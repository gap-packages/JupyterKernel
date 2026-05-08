#
# JupyterKernel: Jupyter kernel using ZeroMQ
#
# Reading the implementation part of the package.
#
# JupyterUtil.gi defines JupyterLog, which the rest of the package
# depends on for diagnostic tracing — load it first.
ReadPackage( "JupyterKernel", "gap/JupyterUtil.gi");
ReadPackage( "JupyterKernel", "gap/JupyterStream.gi");
ReadPackage( "JupyterKernel", "gap/JupyterMsg.gi");
ReadPackage( "JupyterKernel", "gap/JupyterKernel.gi");
ReadPackage( "JupyterKernel", "gap/JupyterHelp.gi");
ReadPackage( "JupyterKernel", "gap/JupyterCompletion.gi");
ReadPackage( "JupyterKernel", "gap/JupyterInspection.gi");
ReadPackage( "JupyterKernel", "gap/JupyterRenderable.gi");

