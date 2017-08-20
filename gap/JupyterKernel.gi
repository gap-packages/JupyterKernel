#
# JupyterKernel: Jupyter kernel using ZeroMQ
#
# Implementations
#

hdlr := AtomicRecord(rec(
    kernel_info_request := function(kernel, msg)
        msg.header.msg_type := "kernel_info_reply";
        msg.content := rec( protocol_version := "5.0.0"
                        , implementation := "ihpcgap"
                        , implementation_version := "0.0.0"
                        , language_info := rec (
                                name := "GAP (native)"
                                , version := GAPInfo.Version
                                , mimetype := "text/x-gap"
                                , file_extension := ".g"
                                , pygments_lexer := ""
                                , codemirror_mode := "gap"
                                , nbconvert_exporter := ""
                                )
                        , banner := Concatenation(
                                "GAP JupterZMQ kernel\n",
                                "Running on GAP ", GAPInfo.BuildVersion, "\n",
                                "built on       ", GAPInfo.BuildDateTime, "\n" )
                        , help_links := [ rec( text := "GAP website", url := "https://www.gap-system.org/")
                                        , rec( text := "GAP documentation", url := "https://www.gap-system.org/Doc/doc.html")
                                        , rec( text := "GAP tutorial", url := "https://www.gap-system.org/Manuals/doc/chap0.html")
                                        , rec( text := "GAP reference", url := "https://www.gap-system.org/Manuals/doc/ref/chap0.html") ]
                        );
    end,

    history_request := function(kernel, msg)
        msg.header.msg_type := "history_reply";
        msg.content := rec( history := [] );
    end,

    execute_request := function(kernel, msg)
        local publ, res, str, r, data;

        str := InputTextString(msg.content.code);

        res := READ_ALL_COMMANDS(str, false);

        for r in res do
            if r[1] = true then
                publ := JupyterMsgReply(msg);
                publ.header.msg_type := "display_data";
                if Length(r) = 2 then
                    if IsRecord(r[2]) and IsBound(r[2].json) and r[2].json then
                        data := r[2].data;
                    else
                        data := rec( text\/plain := ViewString(r[2]));
                    fi;
                else
                    data := rec();
                fi;
                publ.content := rec( transient := "stdout"
                                   , data := data
                                   , metadata := rec() );
                publ.key := kernel.key;
                ZmqSendMsg(kernel.iopub, publ);

                publ := JupyterMsgReply(msg);
                publ.header.msg_type := "status";
                publ.content := rec( execution_state := "idle" );
                publ.key := kernel.key;
                ZmqSendMsg(kernel.iopub, publ);
                kernel.execution_count := kernel.execution_count + 1;
            else
                publ := JupyterMsgReply(msg);
                publ.header.msg_type := "stream";
                publ.content := rec( name := "stderr"
                                   , text := "An error happened" );
                publ.key := kernel.key;
                ZmqSendMsg(kernel.iopub, publ);
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
        msg.content := JUPYTER_Inspect( msg.content.code
                                      , msg.content.cursor_pos );
    end,

    complete_request := function(kernel, msg)
        msg.header.msg_type := "complete_reply";
        msg.content := JUPYTER_Complete( msg.content.code
                                       , msg.content.cursor_pos );
    end,

    history_request := function(kernel, msg)
        msg.header.msg_type := "history_reply";
        msg.content := rec();
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
function(configfile)
    local instream, conf, address, kernel, s;

    instream := InputTextFile(configfile);
    conf := JsonStreamToGap(instream);

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

    # Try redirecting stdout/Print output
#    MakeReadWriteGlobal("Print");
#    UnbindGlobal("Print");
#    BindGlobal("Print",
#              function(args...)
#                  local str, ostream, prt;
#                  str := "";
#                  ostream := OutputTextString(str, false);
#                  Add(args, ostream, 1);
#                  CallFuncList(PrintTo, args);
#                  JUPYTER_print(rec( status := "ok",
#                                     result := rec( name := "stdout"
#                                                  , text := str )));
#              end);
#    MakeReadOnlyGlobal("Print");

    JUPYTER_KernelLoop(kernel);
end);

