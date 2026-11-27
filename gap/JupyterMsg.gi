#
# JupyterMsg: Jupyter kernel using ZeroMQ
#
# Implementations
#

# Compute the lowercase hex SHA-256 HMAC over the four canonical
# Jupyter message JSON strings, in protocol order. Used by both encode
# (to sign outgoing messages) and decode (to verify incoming).
InstallGlobalFunction( JUPYTER_ComputeHMAC,
function(key, header, parent_header, metadata, content)
    local digest;
    if key = "" then
        return "";
    fi;
    digest := CRYPTING_SHA256_HMAC( key,
                Concatenation(header, parent_header, metadata, content) );
    return LowercaseString( Concatenation( List(digest, CRYPTING_HexStringIntPad8) ) );
end);

# Returns fail if raw is not a well-formed Jupyter message or its signature
# does not match. Such messages must be dropped without a reply: reporting the
# expected signature to the sender would let it forge messages.
InstallGlobalFunction( JupyterMsgDecode,
function(kernel, raw)
    local result, sl;

    # Capture the ZMQ envelope frames (everything before <IDS|MSG>). On
    # ROUTER sockets (Control, StdIn, and Shell now), the first frame is
    # the originating peer's identity; replies must prepend it so libzmq
    # can route the message back. On DEALER sockets the envelope is empty.
    sl := Position(raw, "<IDS|MSG>");
    if sl = fail or Length(raw) < sl + 5 then
        return fail;
    fi;

    if raw[sl + 1] <> JUPYTER_ComputeHMAC( kernel!.SessionKey,
                                           raw[sl + 2], raw[sl + 3],
                                           raw[sl + 4], raw[sl + 5] ) then
        return fail;
    fi;

    result := rec();
    result.ids  := raw{[1 .. sl - 1]};
    result.hmac := raw[sl + 1];
    result.header        := JsonStringToGap(raw[sl + 2]);
    result.parent_header := JsonStringToGap(raw[sl + 3]);
    result.metadata      := JsonStringToGap(raw[sl + 4]);
    result.content       := JsonStringToGap(raw[sl + 5]);

    return result;
end);

InstallGlobalFunction( JupyterMsgEncode,
function(kernel, msg)
    local raw, header_j, parent_j, meta_j, content_j;

    Assert(0, IsBound(msg.header)        and IsRecord(msg.header));
    Assert(0, IsBound(msg.parent_header) and IsRecord(msg.parent_header));
    Assert(0, IsBound(msg.metadata)      and IsRecord(msg.metadata));
    Assert(0, IsBound(msg.content)       and IsRecord(msg.content));

    header_j  := GapToJsonString(msg.header);
    parent_j  := GapToJsonString(msg.parent_header);
    meta_j    := GapToJsonString(msg.metadata);
    content_j := GapToJsonString(msg.content);

    # ZMQ envelope: for replies on a ROUTER socket the envelope must be the
    # originating peer's identity (captured into msg.ids by JupyterMsgDecode
    # and copied onto the reply by HandleShellMsg/HandleControlMsg). For
    # IOPub (PUB) the first frame is the topic — we use msg.uuid as a per-
    # kernel topic so subscribers can filter, but most subscribe to all.
    raw := [];
    if IsBound(msg.ids) and Length(msg.ids) > 0 then
        Append(raw, msg.ids);
    else
        Add(raw, msg.uuid);
    fi;
    Add(raw, "<IDS|MSG>");
    Add(raw, JUPYTER_ComputeHMAC(msg.key, header_j, parent_j, meta_j, content_j));
    Add(raw, header_j);
    Add(raw, parent_j);
    Add(raw, meta_j);
    Add(raw, content_j);
    return raw;
end);

# Returns fail for a message JupyterMsgDecode rejects.
InstallGlobalFunction(JupyterMsgRecv,
function(kernel, sock)
    local raw, result;
    raw := ZmqReceiveList(sock);
    if IsBound(kernel!.ProtocolLog) then
        AppendTo(kernel!.ProtocolLog, raw);
        AppendTo(kernel!.ProtocolLog, "\n");
    fi;
    result := JupyterMsgDecode(kernel, raw);
    if result = fail then
        JupyterServerLog("dropped malformed or wrongly signed message");
    fi;
    return result;
end);

InstallGlobalFunction(JupyterMsgSend,
function(kernel, sock, msg)
    local raw;
    JupyterLog("sent ", msg.header.msg_type, "\n");
    raw := JupyterMsgEncode(kernel, msg);
    if IsBound(kernel!.ProtocolLog) then
        AppendTo(kernel!.ProtocolLog, raw);
        AppendTo(kernel!.ProtocolLog, "\n");
    fi;
    ZmqSend(sock, raw);
end);

# Create a message template with the necessary fields filled
InstallGlobalFunction(JupyterMsg,
function(kernel, msg_type, parent_header, content, metadata)
    return rec( uuid := kernel!.ZmqIdentity
              , header := rec( username := kernel!.Username
                             , session := kernel!.SessionID
                             , msg_type := msg_type
                             , version := kernel!.ProtocolVersion
                             , date := ISO8601Stamp()
                             , msg_id := HexStringUUID(RandomUUID())
                             )
              , parent_header := parent_header
              , metadata := metadata
              , content := content
              , key := kernel!.SessionKey
              );
end);
