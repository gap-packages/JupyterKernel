#
# JupyterMsg: Jupyter kernel using ZeroMQ
#
# Implementations
#

#X Timeouts on receive?

DeclareGlobalFunction("JupyterMsgDecode");
DeclareGlobalFunction("JupyterMsgEncode");
DeclareGlobalFunction("JupyterMsgReply");

DeclareGlobalFunction("ZmqRecvMsg");
DeclareGlobalFunction("ZmqSendMsg");


