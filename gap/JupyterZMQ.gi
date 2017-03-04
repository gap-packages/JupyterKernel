#
# JupyterZMQ: Jupyter kernel using ZeroMQ
#
# Implementations
#

DeclareGlobalFunction("JUPYTER_completion");
InstallGlobalFunction(JUPYTER_completion,
function(tok)
    local i, ident, scan;

    i := Length(tok);
    while (not (tok[i] in [' ', '.', '='])) and (i > 0) do i := i - 1; od;

    tok := tok{ [i+1..Length(tok)]};

    return Filtered(IDENTS_BOUND_GVARS(), c -> PositionSublist(c, tok) = 1);
end);

hdlr := AtomicRecord(rec(

    kernel_info_request := function(kernel, msg)
        msg.header.msg_type := "kernel_info_reply";
        msg.content := rec( protocol_version := "5.0.0"
                        , implementation := "ihpcgap"
                        , implementation_version := "0.0.0"
                        , language_info := rec (
                                name := "HPC-GAP"
                                , version := GAPInfo.Version
                                , mimetype := "text/gap"
                                , file_extension := ".g"
                                , pygments_lexer := ""
                                , codemirror_mode := ""
                                , nbconvert_exporter := ""
                                )
                        , banner := Concatenation(
                                "GAP JupterZMQ kernel\n",
                                "Running on GAP ", GAPInfo.BuildVersion, "\n",
                                "built on       ", GAPInfo.BuildDateTime, "\n" )
                        );
    end,

    history_request := function(kernel, msg)
        msg.header.msg_type := "history_reply";
        msg.content := rec( history := [] );
    end,

    execute_request := function(kernel, msg)
        local publ, res, str, r;

        str := InputTextString(msg.content.code);

        res := READ_ALL_COMMANDS(str, false);
        
        for r in res do
            if r[1] = true then
                publ := JupyterMsgReply(msg);
                publ.header.msg_type := "display_data";
                publ.content := rec( source := ""
                                   , data := rec( text\/plain := ViewString(r[2])
#                                                , text\/html := "<b>HTML!</b>"
                                                )
                                   , metadata := rec() );

                publ.key := kernel.key;
                ZmqSendMsg(kernel.iopub, publ);

                publ := JupyterMsgReply(msg);
                publ.header.msg_type := "status";
                publ.content := rec( execution_state := "idle" );
                publ.key := kernel.key;
                ZmqSendMsg(kernel.iopub, publ);
                kernel.execution_count := kernel.execution_count + 1;
            fi;
        od;

        msg.header.msg_type := "execute_reply";
        msg.content := rec( status := "ok"
                            , execution_count := kernel.execution_count
                            , user_expressions := rec( res := "bla" )
                            );
    end,

    inspect_request := function(kernel, msg)
        msg.header.msg_type := "inspect_reply";
        msg.content := rec( status := "ok"
                            , found := false
                            , data := rec()
                            , metadata := rec()
                            );
    end,

    complete_request := function(kernel,msg)
        msg.header.msg_type := "complete_reply";
        msg.content := rec( status := "ok"
                          , cursor_start := 5
                          , matches := JUPYTER_completion(msg.content.code) );
    end,

    is_complete_request := function(kernel, msg)
        msg.header.msg_type := "is_complete_reply";
        msg.content := rec( status := "complete" );
    end,

    comm_open := function(kernel, msg)
        msg.header.msg_type := "comm_open";
        msg.content := rec();
    end,

    shutdown_request := function(kernel, msg)
        msg.header.msg_type := "shutdown_reply";
        msg.content := rec( restart := false );
    end
));

handle_shell_msg := function(kernel, msg)
    local hdl_dict, f, t, reply;
    
    reply := rec();
    reply.uuid := msg.uuid;
    reply.sep := msg.sep;
    reply.hmac := "";
    reply.parent_header := msg.header;
    reply.header := StructuralCopy(msg.header);
    reply.metadata := msg.metadata;
    reply.header.uuid := String(RandomUUID());
    reply.content := msg.content;

    t := msg.header.msg_type;

    if IsBound(hdlr.(t)) then
        hdlr.(t)(kernel, reply);
        return reply;
    else
        Print("unhandled message type: ", msg.header.msg_type, "\n");
        return fail;
    fi;
end;

shell_thread := function(kernel, sock)
    local msg, raw, zmq, res, i;

    zmq := ZmqRouterSocket(sock, kernel.uuid);
    while true do
        msg := ZmqRecvMsg(zmq);
        Print("received msg: ", msg.header.msg_type,
              " id: ", msg.header.msg_id,
              " length: ", Length(msg.remainder),
              "\n");

        res := handle_shell_msg(kernel, msg);
        Print("reply msg:    ", msg);
        if res = fail then
            Print("failed to handle message\n");
        else
            ZmqSendMsg(zmq, res);
        fi;

    od;
end;

control_thread := function(kernel, sock)
    local msg, zmq;

    zmq := ZmqRouterSocket(sock);
    while true do
        msg := ZmqReceive(zmq);
        Print("jupyter control:\n", msg, "\n");
    od;
end;

InstallGlobalFunction( JUPYTER_KernelStart_HPC,
function(conf)
    Error("HPC-GAP is not supported with this code.");
end);



InstallGlobalFunction( JUPYTER_KernelLoop,
function(kernel)
    local topoll, poll, i, msg, res;

    topoll := [kernel.control, kernel.shell, kernel.stdin, kernel.hb];
    while true do
        poll := ZmqPoll(topoll, [], 5000);
        if 1 in poll then
            msg := ZmqReceiveList(topoll[1]);
        fi;
        if 2 in poll then
            msg := ZmqRecvMsg(topoll[2]);
            res := handle_shell_msg(kernel, msg);
            if res = fail then
                Print("failed to handle message\n");
            else
                res.key := kernel.key;
                ZmqSendMsg(topoll[2], res);
            fi;
        fi;
        if 3 in poll then
            msg := ZmqReceiveList(topoll[3]);
        fi;
        if 4 in poll then
            msg := ZmqRecvMsg(topoll[4]);
            msg.key := kernel.key;
            ZmqSendMsg(kernel.hb, msg);
        fi;
    od;
end);

InstallGlobalFunction( JUPYTER_KernelStart_GAP,
function(conf)
    local address, kernel, s;

    address := Concatenation(conf.transport, "://", conf.ip, ":");

    kernel := AtomicRecord( rec( config := Immutable(conf)
                               , uuid   := Immutable(String(RandomUUID()))));

    kernel.iopub   := ZmqPublisherSocket(Concatenation(address, String(conf.iopub_port)));
    kernel.control := ZmqRouterSocket(Concatenation(address, String(conf.control_port)));
    kernel.shell   := ZmqRouterSocket(Concatenation(address, String(conf.shell_port)));
    kernel.stdin   := ZmqRouterSocket(Concatenation(address, String(conf.stdin_port)));
    kernel.hb      := ZmqRouterSocket(Concatenation(address, String(conf.hb_port)));
    kernel.key     := conf.key;

    kernel.execution_count := 0;

    JUPYTER_KernelLoop(kernel);
end);
