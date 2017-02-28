#
# JupyterZMQ: Jupyter kernel using ZeroMQ
#
# Reading the implementation part of the package.
#
ReadPackage( "JupyterZMQ", "gap/JupyterMsg.gi");
ReadPackage( "JupyterZMQ", "gap/JupyterHB.gi");
ReadPackage( "JupyterZMQ", "gap/JupyterZMQ.gi");

#X Hack
# jkernel := JupyterKernelStart(JupyterDefaultKernelConfig);
Print("""
 /!\ To Start Jupyter kernel start JupyterKernelStart /!\

   jupyter notebook --existing /tmp/xxx.json

""");

