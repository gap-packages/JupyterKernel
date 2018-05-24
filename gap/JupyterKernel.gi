#
# JupyterKernel: Jupyter kernel using ZeroMQ
#
# Implementations
#
# TODO:
#  * InfoLevel and Debug messages

_KERNEL := "";


InstallGlobalFunction( NewJupyterKernel,
function(conf)
    local pid, address, kernel, poll, msg, status;

    address := Concatenation(conf.transport, "://", conf.ip, ":");

    # This should happen in "Run" somehow, as currently the creation
    # of a Jupyter Kernel breaks the running GAP session, taking
    # every hope of debugging the kernel
    pid := IO_fork();
    if pid = fail then
        return fail;
    elif pid > 0 then # we are the parent and do heartbeat
        kernel := rec();
        kernel.HB := ZmqRouterSocket( Concatenation(address, String(conf.hb_port)) );
        while true do
            poll := ZmqPoll([ kernel!.HB ], [], 1000);
            if 1 in poll then
                msg := ZmqReceiveList(kernel!.HB);
                ZmqSend(kernel!.HB, msg);
            fi;
            status := IO_WaitPid(pid, false);
            if IsRecord(status) then
                if status.pid = pid and status.status = 15 then
                    QUIT_GAP(0);
                fi;
            fi;
        od;
    else

    kernel := rec( config := Immutable(conf)
                 , Username := "username"
                 , ProtocolVersion := "5.3"
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
    # Jupyter Heartbeat is handled by a fork'ed GAP process (yes, really, its better than
    # starting a separate thread, because it doesn't need special pthread code
    # downside is that it doesn't work on cygwin, of course, but maybe we could just
    # ExecuteProcess on windows, or wait for bash on windows to become popular enoug.
    # kernel.HB      := ZmqRouterSocket( Concatenation(address, String(conf.hb_port))
    #                                  , kernel.ZmqIdentity);

    kernel.MsgHandlers := rec( kernel_info_request := function(msg)
                                 kernel!.SessionID := msg.header.session;
                                 return JupyterMsg( kernel
                                                  , "kernel_info_reply"
                                                  , msg.header
                                                  , rec( protocol_version := kernel!.ProtocolVersion
                                                       , implementation := "GAP"
                                                       , implementation_version := "1.1.0"
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
                                   local publ, res, rep, r, str, data, metadata;

                                   JupyterMsgSend(kernel, kernel!.IOPub, JupyterMsg( kernel
                                                                       , "execute_input"
                                                                       , msg.header
                                                                       , rec( code := msg.content.code
                                                                            , execution_count := kernel!.ExecutionCount )
                                                                       , rec() ) );
                                   str := InputTextString(msg.content.code);

                                   res := READ_ALL_COMMANDS(str, false);
                                   for r in res do
                                       if r[1] = true then
                                           kernel!.ExecutionCount := kernel!.ExecutionCount + 1;

                                           # r[2] contains the result, r[3] is true if a dual semicolon was parsed
                                           if IsBound(r[2]) and r[3] = false then
                                               # FIXME: This is probably doable slightly more nicely
                                               rep := JupyterRender(r[2]);
                                               metadata := JupyterRenderableMetadata(rep);
                                               data := JupyterRenderableData(rep);
                                               # Only send a result message when there is a result
                                               # value
                                               # publ.execution_count := kernel!.ExecutionCount;
                                               JupyterMsgSend(kernel, kernel!.IOPub, JupyterMsg( kernel
                                                                                   , "execute_result"
                                                                                   , msg.header
                                                                                   , rec( transient := rec()
                                                                                        , data := data
                                                                                        , metadata := metadata
                                                                                        , execution_count := kernel!.ExecutionCount )
                                                                                   , rec() ) );
                                           fi;
                                       fi;
                                   od;
                                   # Flush StdOut...
                                   Print("\c");
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
                                                    , rec( history := [] )
                                                    , rec() );
                               end,

                               is_complete_request := function(msg)
                                   return JupyterMsg( kernel
                                                    , "is_complete_reply"
                                                    , msg.header
                                                    , rec( status := "complete" )
                                                    , rec() );
                               end,

                               comm_open := function(msg)
                                   return JupyterMsg( kernel
                                                    , "comm_open_reply"
                                                    , msg.header
                                                    , rec( status := "ok" )
                                                    , rec() );
                               end,

                               comm_info_request := function(msg)
                                   return JupyterMsg( kernel
                                                    , "comm_info_reply"
                                                    , msg.header
                                                    , rec( status := "ok" )
                                                    , rec() );
                               end,

                               shutdown_request := function(msg)
                                   JupyterMsgSend( kernel
                                                 , "shutdown_reply"
                                                 , msg.header
                                                 , rec( status := "ok" )
                                                 , rec() );
                                   QUIT_GAP(0);
                               end );

    kernel.SignalBusy := function()
        JupyterMsgSend( kernel, kernel!.IOPub
                      , JupyterMsg( kernel
                                  , "status"
                                  , kernel!.CurrentMsg
                                  , rec( execution_state := "busy" )
                                  , rec() ) );
    end;
    kernel.SignalIdle := function()
        JupyterMsgSend( kernel, kernel!.IOPub
                      , JupyterMsg( kernel
                                  , "status"
                                  , kernel!.CurrentMsg
                                  , rec( execution_state := "idle" )
                                  , rec() ) );
    end;

    kernel.HandleShellMsg := function(msg)
        local hdl_dict, f, t, reply;

        # We store the currently processed
        # message header, because we need it
        # for replies
        kernel!.CurrentMsg := msg.header;

        kernel!.SignalBusy();
        t := msg.header.msg_type;
        if IsBound(kernel!.MsgHandlers.(t)) then
            # Currently we send the "reply" to each "request" on the Shell socket
            # here. We might opt to move the sending into the handler functions,
            # since at least "execute" has to send more than one message anyway
            JupyterMsgSend(kernel, kernel!.Shell, kernel!.MsgHandlers.(t)(msg) );

            kernel!.SignalIdle();
            return true;
        else
            Print("unhandled message type: ", msg.header.msg_type, "\n");
            kernel!.SignalIdle();
            return fail;
        fi;

    end;

    kernel.Loop := function()
        local topoll, poll, i, msg, res;

        topoll := [ kernel!.Control, kernel!.Shell, kernel!.StdIn ];
        # Heartbeat now handled differently
        # , kernel!.HB ];
        while true do
            poll := ZmqPoll(topoll, [], 5000);
            if 1 in poll then
                msg := ZmqReceiveList(topoll[1]);
            fi;
            if 2 in poll then
                msg := JupyterMsgRecv(kernel, topoll[2]);
                res := kernel!.HandleShellMsg(msg);
                if res = fail then
                    Print("failed to handle message\n");
                fi;
            fi;
            if 3 in poll then
                msg := ZmqReceiveList(topoll[3]);
            fi;
        od;
    end;

    _KERNEL := kernel;
    # TODO: This is of course still hacky, but better than before
    kernel!.StdOut := OutputStreamZmq(kernel, kernel!.IOPub);
    kernel!.StdErr := OutputStreamZmq(kernel, kernel!.IOPub, "stderr");
    OutputLogTo(kernel!.StdOut);

    GAP_ERROR_STREAM := kernel!.StdErr;

    Objectify(GAPJupyterKernelType, kernel);
    return kernel;
    fi;
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
