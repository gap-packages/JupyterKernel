#
# JupyterMsg: Jupyter kernel using ZeroMQ
#
# Implementations
#
InstallGlobalFunction( JupyterMsgDecode,
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

InstallGlobalFunction( JupyterMsgEncode,
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
        return JupyterMsgDecode(raw);
    end);

InstallGlobalFunction(ZmqSendMsg,
    function(sock, msg)
        ZmqSend(sock, JupyterMsgEncode(msg));
    end);

# Construct a reply for msg
InstallGlobalFunction(JupyterMsgReply,
    function(msg)
        local reply;

        reply := rec();
        reply.header := StructuralCopy(msg.header);
        reply.header.uuid := StringUUID(RandomUUID());
        reply.uuid := msg.uuid;
        reply.sep := "<IDS|MSG>";
        reply.hmac := "";
        reply.parent_header := msg.header;
        reply.metadata := msg.metadata;

        return reply;
    end);
