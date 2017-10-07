#
# JupyterKernel: Jupyter kernel using ZeroMQ
#
# Implementations
#
# TODO:
#  * InfoLevel and Debug messages

InstallGlobalFunction( NewJupyterKernel,
function(conf)
    local pid, address, kernel, poll, msg;

    address := Concatenation(conf.transport, "://", conf.ip, ":");

    pid := IO_fork();
    if pid = fail then
        return fail;
    elif pid > 0 then # we are the parent and do heartbeat
        kernel := rec();
        kernel.HB := ZmqRouterSocket( Concatenation(address, String(conf.hb_port)) );
        while true do
            poll := ZmqPoll([ kernel!.HB ], [], 5000);
            if 1 in poll then
                msg := ZmqRecvMsg(kernel!.HB);
                msg.key := conf.key;
                ZmqSendMsg(kernel!.HB, msg);
            fi;
        od;
    else

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

    # TODO: Hack. Sends a message to the stderr stream
    #       And is currently used to send captured error
    #       messages
    kernel.ErrorOutput := function(text)
        local curmsg;
        if IsBound(kernel!.CurrentMsg) then
            curmsg := kernel!.CurrentMsg;
        else
            curmsg := rec();
        fi;
        ZmqSendMsg(kernel!.IOPub
                  , JupyterMsg( kernel
                              , "stream"
                              , curmsg
                              , rec( name := "stderr"
                                   , text := text )
                              , rec() ) );
    end;
    kernel.StandardOutput := function(text)
        local curmsg;
        if IsBound(kernel!.CurrentMsg) then
            curmsg := kernel!.CurrentMsg;
        else
            curmsg := rec();
        fi;
        ZmqSendMsg(kernel!.IOPub
                  , JupyterMsg( kernel
                              , "stream"
                              , curmsg
                              , rec( name := "stdout"
                                   , text := text )
                              , rec() ) );
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

        topoll := [ kernel!.Control, kernel!.Shell, kernel!.StdIn ];
        # Heartbeat now handled differently
        # , kernel!.HB ];
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
        od;
    end;

    # TODO: This is of course very hacky
    #       The solution I would like to implement involves defining
    #       *stdout* and *errout* as proper gap stream that can be
    #       captured. This also almost works and is work in progress
 
    # Try redirecting stdout/Print output
    # This will of course completely muck up any hope of debugging...
    MakeReadWriteGlobal("Print");
    UnbindGlobal("Print");
    BindGlobal("Print", function(args...)
                  kernel!.StandardOutput(CallFuncList(STRINGIFY, args));
              end);
    MakeReadOnlyGlobal("Print");

    MakeReadWriteGlobal("Error");
    UnbindGlobal("Error");
    BindGlobal("Error", function(args...)
                  kernel!.ErrorOutput(CallFuncList(STRINGIFY, args));
              end);

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
