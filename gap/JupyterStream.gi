
_BUFFER := "";
OutputStreamZmqType := NewType(
    StreamsFamily,
    IsOutputTextStream and IsOutputStreamZmqRep );

InstallMethod( OutputStreamZmq,
    "output stream to Jupyter ZeroMQ",
    [ IsObject, IsZmqSocket, IsString ],
function(kernel, socket, streamname)
    # TODO: more specific, check kernel, connected socket, etc
    if not IsZmqSocket(socket)  then
        Error( "<socket> must be a IsZmqSocket" );
    fi;
    return Objectify( OutputStreamZmqType
                    , rec( kernel := kernel, socket := socket
                         , format := false, streamname := streamname ) );
end);


InstallMethod( OutputStreamZmq,
    "output stream to Jupyter ZeroMQ",
    [ IsObject, IsZmqSocket ],
    { kernel, socket } -> OutputStreamZmq(kernel, socket, "stdout" ) );

InstallMethod( ViewString,
    "output stream to Jupyter ZeroMQ",
    [ IsOutputStreamZmqRep ],
function( obj )
    # TODO: print some useful info about kernel/socket?
    return "OutputStreamZmq()";
end );

InstallMethod( WriteAll,
    "output text string",
    [ IsOutputTextStream and IsOutputStreamZmqRep,
      IsString ],
function( stream, string )
    local curmsg, msg;
    if IsBound(stream!.kernel!.CurrentMsg) then
        curmsg := stream!.kernel!.CurrentMsg;
    else
        curmsg := rec();
    fi;
    Append( _BUFFER, string );
    JupyterMsgSend( stream!.kernel
                  , stream!.kernel!.IOPub
                  , JupyterMsg( stream!.kernel
                              , "stream"
                              , curmsg
                              , rec( name := stream!.streamname
                                   , text := string )
                              , rec () ) );
    return true;
end );

InstallMethod( WriteByte,
    "output text string",
    [ IsOutputTextStream and IsOutputStreamZmqRep,
      IsInt ],
function(stream, byte)
    local curmsg, msg;
    if byte < 0 or 255 < byte  then
        Error( "<byte> must an integer between 0 and 255" );
    fi;
    # TODO
    if IsBound(stream!.kernel!.CurrentMsg) then
        curmsg := stream!.kernel!.CurrentMsg;
    else
        curmsg := rec();
    fi;
    Add( _BUFFER, CharInt(byte) );
    JupyterMsgSend( stream!.kernel
                  , stream!.kernel!.IOPub
                  , JupyterMsg( stream!.kernel
                              , "stream"
                              , curmsg
                              , rec( name := stream!.streamname
                                   , text := CharInt(byte) )
                              , rec () ) );

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


