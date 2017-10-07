#
# JupyterMsg: Jupyter kernel using ZeroMQ
#
# Implementations
#
# TODO: Check signature
InstallGlobalFunction( JupyterMsgDecode,
function(raw)
    local result, bindIfBound, sl, ids;

    bindIfBound := function(name, pos)
        if IsBound(raw[pos]) then
            result.(name) := JsonStringToGap(raw[pos]);
        fi;
    end;

    result := rec();

    ids := [];
    sl := 1;
    while raw[sl] <> "<IDS|MSG>" do
        Add(ids, raw[sl]);
        sl := sl + 1;
    od;
    result.hmac := raw[sl + 1];
    result.remainder := raw;

    bindIfBound("header", sl + 2);
    bindIfBound("parent_header", sl + 3);
    bindIfBound("metadata", sl + 4);
    bindIfBound("content", sl + 5);

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
    # TODO: What is the correct behaviour here?
    if IsBound(msg.uuid) then
        raw[1] := msg.uuid;
    else
        raw[1] := "";
    fi;
    raw[2] := "<IDS|MSG>";
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

# This is really not what I should be doing here...
ISO8601Stamp := function()
    local tz, gm, pad;

    tz := IO_gettimeofday();
    pad := function(i, l, c)
        local s;
        s := String(i);
        if Length(s) < l then
            return Concatenation(RepeatedString(c, l - Length(s)), s);
        else
            return s;
        fi;
    end;

    gm := IO_gmtime(tz.tv_sec);
    return STRINGIFY( 1900 + gm.tm_year, "-"
                      , pad(gm.tm_mon + 1, 2, '0'), "-"
                      , pad(gm.tm_mday, 2, '0'), "T"
                      , pad(gm.tm_hour, 2, '0'), ":"
                      , pad(gm.tm_min, 2, '0'), ":"
                      , pad(gm.tm_sec, 2, '0'), "."
                      , pad(tz.tv_usec, 6, '0') );
end;

# Create a message template with the necessasry fields filled
InstallGlobalFunction(JupyterMsg,
function(kernel, msg_type)
    return rec( uuid := kernel!.ZmqIdentity
              , sep := "<IDS|MSG>"                 # This could be in JupyterEncode
              , hmac := ""
              , header := rec( username := kernel!.Username
                             , session := kernel!.SessionID
                             , msg_type := msg_type
                             , version := kernel!.ProtocolVersion
                             , date := ISO8601Stamp()
                             , msg_id := HexStringUUID(RandomUUID())
                             )
              , parent_header := rec()
#               , msg_id := HexStringUUID(RandomUUID())
              , metadata := rec( )
              , content := rec( )
              , key := kernel!.SessionKey
                             # This shouldn't be here as all
                             # messaging functions
                             # should just be running in kernel context
              );
end);


# Construct a reply for msg
InstallGlobalFunction(JupyterMsgReply,
function(kernel, parent_header, msg_type)
    local reply;

    reply := JupyterMsg(kernel, msg_type);
    reply.parent_header := parent_header;

    return reply;
end);
