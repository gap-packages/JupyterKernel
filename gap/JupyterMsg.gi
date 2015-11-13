#
# JupyterMsg: Jupyter kernel using ZeroMQ
#
# Implementations
#
InstallGlobalFunction( DecodeJupyterMsg,
    function(raw)
        return rec( uuid := raw[1]
                , sep := raw[2]
                , hmac := raw[3]
                , header := JsonStringToGap(raw[4])
                , parent_header := JsonStringToGap(raw[5])
                , metadata := JsonStringToGap(raw[6])
                , content := JsonStringToGap(raw[7])
                , remainder := raw
                );
    end);

InstallGlobalFunction( EncodeJupyterMsg,
    function(msg)
        local raw;

        raw := [];
        raw[1] := msg.uuid;
        raw[2] := msg.sep;
        raw[3] := msg.hmac;
        raw[4] := GapToJsonString(msg.header);
        raw[5] := GapToJsonString(msg.parent_header);
        raw[6] := GapToJsonString(msg.metadata);
        raw[7] := GapToJsonString(msg.content);

        return raw;
    end);

InstallGlobalFunction(ZmqRecvMsg,
    function(sock)
        local raw;
        raw := ZmqReceiveList(sock);
        return (DecodeJupyterMsg(raw));
    end);

InstallGlobalFunction(ZmqSendMsg,
    function(sock, msg)
        ZmqSend(sock, EncodeJupyterMsg(msg));
    end);
