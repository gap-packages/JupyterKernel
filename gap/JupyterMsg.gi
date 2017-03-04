#
# JupyterMsg: Jupyter kernel using ZeroMQ
#
# Implementations
#
# TODO: Check signature
InstallGlobalFunction( JupyterMsgDecode,
function(raw)
    local result, bindIfBound;

    bindIfBound := function(name, pos)
        if IsBound(raw[pos]) then
            result.(name) := JsonStringToGap(raw[pos]);
        fi;
    end;

    result := rec();
    result.uuid := raw[1];
    result.sep  := raw[2];
    result.hmac := raw[3];
    result.remainder := raw;

    bindIfBound("header", 4);
    bindIfBound("parent_header", 5);
    bindIfBound("metadata", 6);
    bindIfBound("content", 7);

    return result;
end);

InstallGlobalFunction( JupyterMsgEncode,
function(msg)
    local raw, k, bindIfBound, tmp;

    bindIfBound := function(pos, name)
        if IsBound(msg.(name)) then
            raw[pos] := GapToJsonString(msg.(name));
        fi;
    end;

    raw := [];
    raw[1] := msg.uuid;
    raw[2] := msg.sep;
    raw[3] := msg.hmac;
    bindIfBound(4, "header");
    bindIfBound(5, "parent_header");
    bindIfBound(6, "metadata");
    bindIfBound(7, "content");

    # TODO: Ugly
    if Length(raw) > 3 then
        tmp := CRYPTING_SHA256_HMAC(msg.key,
                                    Concatenation( raw[4]
                                                 , raw[5]
                                                 , raw[6]
                                                 , raw[7]));
        tmp := List(tmp, CRYPTING_HexStringIntPad8);
        tmp := LowercaseString(Concatenation(tmp));
        raw[3] := LowercaseString(tmp);
    fi;

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
