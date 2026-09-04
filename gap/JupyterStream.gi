OutputStreamZmqType := NewType(
    StreamsFamily,
    IsOutputTextStream and IsOutputStreamZmqRep );

JUPYTER_STREAM_FLUSH_THRESHOLD := 4096;

InstallMethod( OutputStreamZmq,
    "output stream to Jupyter ZeroMQ",
    [ IsObject, IsZmqSocket, IsString ],
function(kernel, socket, streamname)
    if not IsZmqSocket(socket)  then
        Error( "<socket> must be a IsZmqSocket" );
    fi;
    return Objectify( OutputStreamZmqType
                    , rec( kernel := kernel
                         , socket := socket
                         , format := false
                         , streamname := streamname
                         , buffer := "" ) );
end);


InstallMethod( OutputStreamZmq,
    "output stream to Jupyter ZeroMQ",
    [ IsObject, IsZmqSocket ],
    { kernel, socket } -> OutputStreamZmq(kernel, socket, "stdout" ) );

InstallMethod( ViewString,
    "output stream to Jupyter ZeroMQ",
    [ IsOutputStreamZmqRep ],
function( obj )
    return Concatenation("OutputStreamZmq(", obj!.streamname, ")");
end );

InstallMethod( FlushOutputStream,
    "send buffered output as one stream message",
    [ IsOutputStreamZmqRep ],
function( stream )
    local curmsg, text, c;
    if Length(stream!.buffer) = 0 then
        return;
    fi;
    if stream!.kernel!.Silent then
        stream!.buffer := "";
        return;
    fi;
    if IsBound(stream!.kernel!.CurrentMsg) then
        curmsg := stream!.kernel!.CurrentMsg;
    else
        curmsg := rec();
    fi;
    # GAP's scanner uses byte 0xFF (\377) as its end-of-input sentinel.
    # On certain syntax errors — most reliably ones involving a missing
    # trailing token, e.g. `h := ;` — the sentinel still sits in the
    # input-line buffer that SyntaxErrorOrWarning() prints verbatim
    # alongside the error message. JSON/UTF-8 has no encoding for a
    # stray 0xFF, so the front-end renders it as `ÿ`. Drop those bytes
    # before sending.
    text := "";
    for c in stream!.buffer do
        if IntChar(c) <> 255 then
            Add(text, c);
        fi;
    od;
    JupyterMsgSend( stream!.kernel
                  , stream!.socket
                  , JupyterMsg( stream!.kernel
                              , "stream"
                              , curmsg
                              , rec( name := stream!.streamname
                                   , text := text )
                              , rec() ) );
    stream!.buffer := "";
end );

InstallMethod( WriteAll,
    "output text string",
    [ IsOutputTextStream and IsOutputStreamZmqRep,
      IsString ],
function( stream, string )
    JupyterLog("        WriteAll(", stream!.streamname,
               ", len=", Length(string), ", '",
               string{[1..Minimum(80, Length(string))]}, "')\n");
    Append( stream!.buffer, string );
    if Length(stream!.buffer) >= JUPYTER_STREAM_FLUSH_THRESHOLD
       or '\n' in string then
        JupyterLog("        WriteAll: flushing\n");
        FlushOutputStream(stream);
    fi;
    return true;
end );

InstallMethod( WriteByte,
    "output text byte",
    [ IsOutputTextStream and IsOutputStreamZmqRep,
      IsInt ],
function(stream, byte)
    if byte < 0 or 255 < byte then
        Error( "<byte> must be an integer between 0 and 255" );
    fi;
    Add( stream!.buffer, CharInt(byte) );
    if byte = INT_CHAR('\n')
       or Length(stream!.buffer) >= JUPYTER_STREAM_FLUSH_THRESHOLD then
        FlushOutputStream(stream);
    fi;
    return true;
end );

InstallMethod( PrintFormattingStatus, "output text string"
             , [ IsOutputTextStream and IsOutputStreamZmqRep ]
             , str -> str!.format);

InstallMethod( SetPrintFormattingStatus, "output text string"
             , [ IsOutputTextStream and IsOutputStreamZmqRep,
                 IsBool ],
function(str, stat)
    if stat = fail then
        Error("Print formatting status must be true or false");
    else
        str!.format := stat;
    fi;
end);
