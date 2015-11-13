#
# JupyterZMQ: Jupyter kernel using ZeroMQ
#
# Implementations
#

#X Thread termination?
InstallGlobalFunction( JupyterHBThreadFunc,
    function(kernel)
        local msg, zsock, zaddr;

        atomic kernel do
            zaddr := Concatenation(
                kernel.config.transport, "://"
                , kernel.config.ip, ":"
                , String(kernel.config.hb_port)
                );
        od;
        zsock := ZmqRouterSocket(zaddr);
        while true do
            msg := ZmqReceiveList(zsock);
            Print("hb: ping.");
            ZmqSend(zsock, msg);
            Print(" pong.\n");
        od;
    end);
