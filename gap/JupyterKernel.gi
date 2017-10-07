#
# JupyterKernel: Jupyter kernel using ZeroMQ
#
# Implementations
#
# TODO:
#  * InfoLevel and Debug messages

InstallGlobalFunction( NewJupyterKernel,
function(conf)
    local address, kernel;

    address := Concatenation(conf.transport, "://", conf.ip, ":");

    kernel := rec( config := Immutable(conf)
                 , Username := "username"
                 , ProtocolVersion := "5.0"
                 , ZmqIdentity := HexStringUUID( RandomUUID() )
                 , SessionKey := conf.key
                 , SessionID := ""
                 , ExecutionCount := 0);

    kernel.IOPub   := ZmqPublisherSocket( Concatenation(address, String(conf.iopub_port))
                                        , kernel.ZmqIdentity);
    kernel.Control := ZmqRouterSocket( Concatenation(address, String(conf.control_port))
                                     , kernel.ZmqIdentity);
    kernel.Shell   := ZmqDealerSocket( Concatenation(address, String(conf.shell_port))
                                     , kernel.ZmqIdentity);
    kernel.StdIn   := ZmqRouterSocket( Concatenation(address, String(conf.stdin_port))
                                     , kernel.ZmqIdentity);
    kernel.HB      := ZmqRouterSocket( Concatenation(address, String(conf.hb_port))
                                     , kernel.ZmqIdentity);

    kernel.MsgHandlers := rec( kernel_info_request := function(msg)
                                 kernel!.SessionID := msg.header.session;
                                 return JupyterMsg( kernel
                                                  , "kernel_info_reply"
                                                  , msg.header
                                                  , rec( protocol_version := kernel!.ProtocolVersion
                                                       , implementation := "GAP"
                                                       , implementation_version := "1.0.0"
                                                       , language_info := rec( name := "GAP (native)"
                                                                             , version := GAPInfo.Version
                                                                             , mimetype := "text/x-gap"
                                                                             , file_extension := ".g"
                                                                             , pygments_lexer := "gap"
                                                                             , codemirror_mode := "gap"
                                                                             , nbconvert_exporter := "" )
                                                       , banner := Concatenation( "GAP JupterZMQ kernel\n",
                                                                                  "Running on GAP ", GAPInfo.BuildVersion, "\n",
                                                                                  "built on       ", GAPInfo.BuildDateTime, "\n" )
                                                       , help_links := [ rec( text := "GAP website", url := "https://www.gap-system.org/")
                                                                       , rec( text := "GAP documentation", url := "https://www.gap-system.org/Doc/doc.html")
                                                                       , rec( text := "GAP tutorial", url := "https://www.gap-system.org/Manuals/doc/chap0.html")
                                                                       , rec( text := "GAP reference", url := "https://www.gap-system.org/Manuals/doc/ref/chap0.html") ]
                                                       , status := "ok" )
                                                  , rec() );
                               end,

                               history_request := function(msg)
                                   msg.header.msg_type := "history_reply";
                                   msg.content := rec( history := [] );
                               end,

                               execute_request := function(msg)
                                   local publ, res, str, r, data;

                                   publ := JupyterMsg( kernel
                                                     , "execute_input"
                                                     , msg.header
                                                     , rec( code := msg.content.code
                                                          , execution_count := kernel!.ExecutionCount )
                                                     , rec() );
                                   ZmqSendMsg(kernel!.IOPub, publ);

                                   str := InputTextString(msg.content.code);

                                   res := READ_ALL_COMMANDS(str, false);
                                   for r in res do
                                       if r[1] = true then
                                           kernel!.ExecutionCount := kernel!.ExecutionCount + 1;

                                           if Length(r) = 2 then
                                               if IsRecord(r[2]) and IsBound(r[2].json) and r[2].json then
                                                   data := r[2].data;
                                               else
                                                   data := rec( text\/plain := ViewString(r[2]));
                                               fi;
                                           else
                                               data := rec();
                                           fi;
                                           # publ.execution_count := kernel!.ExecutionCount;
                                           publ := JupyterMsg( kernel
                                                             , "execute_result"
                                                             , msg.header
                                                             , rec( transient := "stdout"
                                                                  , data := data
                                                                  , metadata := rec()
                                                                  , execution_count := kernel!.ExecutionCount )
                                                             , rec() );
                                           ZmqSendMsg(kernel!.IOPub, publ);
                                       else
                                           publ := JupyterMsg( kernel
                                                             , "stream"
                                                             , msg.header
                                                             , rec( name := "stderr"
                                                                  , text := "An error happened" )
                                                             , rec() );
                                           ZmqSendMsg(kernel!.IOPub, publ);
                                       fi;
                                   od;
                                   publ := JupyterMsg( kernel
                                                     , "execute_reply"
                                                     , msg.header
                                                     , rec( status := "ok"
                                                          , execution_count := kernel!.ExecutionCount )
                                                     , rec() );
                                   return publ;
                               end,

                               inspect_request := function(msg)
                                   return JupyterMsg( kernel
                                                    , "inspect_reply"
                                                    , msg.header
                                                    , JUPYTER_Inspect( msg.content.code
                                                                     , msg.content.cursor_pos )
                                                    , rec() );
                               end,

                               complete_request := function(msg)
                                   return JupyterMsg( kernel
                                                    , "complete_reply"
                                                    , msg.header
                                                    , JUPYTER_Complete( msg.content.code
                                                                      , msg.content.cursor_pos )
                                                    , rec() );
                               end,

                               history_request := function(msg)
                                   return JupyterMsg( kernel
                                                    , "history_reply"
                                                    , msg.header
                                                    , rec( status := "ok" )
                                                    , rec() );
                               end,

                               is_complete_request := function(msg)
                                   return JupyterMsg( kernel
                                                    , "is_complete_reply"
                                                    , msg.header
                                                    , rec( status := "ok" )
                                                    , rec() );
                               end,

                               comm_open := function(msg)
                                   return JupyterMsg( kernel
                                                    , "is_complete_reply"
                                                    , msg.header
                                                    , rec( status := "ok" )
                                                    , rec() );
                               end,

                               shutdown_request := function(msg)
                                   return JupyterMsg( kernel
                                                    , "shutdown_reply"
                                                    , msg.header
                                                    , rec( status := "error" ) # Currently not supported
                                                    , rec() );
                               end );

    # TODO:
    # kernel.StandardOutput := stream
    # kernel.StandardError := stream

    # TODO: Hack, remove
    kernel.SignalError := function(text)
        local msg;

        msg := JupyterMsg(kernel, "stream");
        if IsBound(kernel!.CurrentMsg) then
            msg.parent_header := kernel!.CurrentMsg;
        fi;
        msg.content := rec( name := "stderr"
                          , text := text);
        ZmqSendMsg(kernel!.IOPub, msg);
    end;

    kernel.HandleShellMsg := function(msg)
        local hdl_dict, f, t, reply;

        # We store the currently processed
        # message header, because we need it
        # for replies
        kernel!.CurrentMsg := msg.header;

        t := msg.header.msg_type;

        if IsBound(kernel!.MsgHandlers.(t)) then
            return kernel!.MsgHandlers.(t)(msg);
        else
            Print("unhandled message type: ", msg.header.msg_type, "\n");
            return fail;
        fi;
    end;

    kernel.Loop := function()
        local topoll, poll, i, msg, res;

        topoll := [ kernel!.Control, kernel!.Shell, kernel!.StdIn, kernel!.HB ];
        while true do
            poll := ZmqPoll(topoll, [], 5000);
            if 1 in poll then
                msg := ZmqReceiveList(topoll[1]);
            fi;
            if 2 in poll then
                msg := ZmqRecvMsg(topoll[2]);
                res := kernel!.HandleShellMsg(msg);
                if res = fail then
                    Print("failed to handle message\n");
                else
                    ZmqSendMsg(topoll[2], res);
                fi;
            fi;
            if 3 in poll then
                msg := ZmqReceiveList(topoll[3]);
            fi;
            if 4 in poll then
                msg := ZmqRecvMsg(topoll[4]);
                msg.key := kernel!.SessionKey;
                ZmqSendMsg(kernel!.HB, msg);
            fi;
        od;
    end;

    # TODO: Also a hack...

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

    # This is of course very hacky
    # kernel.origerror := Error;
    # MakeReadWriteGlobal("Error");
    # UnbindGlobal("Error");
    # BindGlobal("Error",
    #          function(args...)
    #              kernel.SignalError(CallFuncList(STRINGIFY, args));
    #          end);

    Objectify(GAPJupyterKernelType, kernel);
    return kernel;
end);

InstallMethod( ViewString
             , "for Jupyter kernels"
             , [ IsGAPJupyterKernel ]
             , x -> "<GAP Jupyter Kernel>" );

InstallMethod( Run
             , "for Jupyter kernel"
             , [ IsGAPJupyterKernel ]
             , x -> x!.Loop() );


InstallGlobalFunction( JUPYTER_KernelStart_HPC,
function(conf)
    Error("HPC-GAP is not supported with this code.");
    QUIT_GAP(0);
end);

InstallGlobalFunction( JUPYTER_KernelStart_GAP,
function(configfile)
    local instream, conf, address, kernel, s;

    instream := InputTextFile(configfile);
    conf := JsonStreamToGap(instream);

    kernel := NewJupyterKernel(conf);
    Run(kernel);
end);


# TODO: These are leftovers from the original HPC-GAP code
#       and they should be folded into a new HPC-GAP implementation
#       that handles heartbeat and shell separately
#
#       Ideally code duplication between GAP and HPC-GAP should be
#       very minimal
#
#shell_thread := function(kernel, sock)
#    local msg, raw, zmq, res, i;
#
#    zmq := ZmqRouterSocket(sock, kernel.uuid);
#    while true do
#        msg := ZmqRecvMsg(zmq);
#        Print("received msg: ", msg.header.msg_type,
#              " id: ", msg.header.msg_id,
#              " length: ", Length(msg.remainder),
#              "\n");
#
#        res := handle_shell_msg(kernel, msg);
#        Print("reply msg:    ", msg);
#        if res = fail then
#            Print("failed to handle message\n");
#        else
#            ZmqSendMsg(zmq, res);
#        fi;
#
#    od;
#end;
#
#control_thread := function(kernel, sock)
#    local msg, zmq;
#
#    zmq := ZmqRouterSocket(sock);
#    while true do
#        msg := ZmqReceive(zmq);
#        Print("jupyter control:\n", msg, "\n");
#    od;
#end;

