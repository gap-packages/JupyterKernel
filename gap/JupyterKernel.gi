#
# JupyterKernel: Jupyter kernel using ZeroMQ
#
# Implementations
#

# This is a bit ugly: The global variable _KERNEL is assigned to
# the jupyter kernel object at so that we can use it from everywhere.
_KERNEL := "";

## This is plainly wrong, it just reessembles the behaviour of
## `UPDATE_STAT` in newer GAP version we need here.
if not IsBound( UPDATE_STAT ) then
    BindGlobal( "UPDATE_STAT",
      function( string, value )
        time := value;
    end );
fi;


BindConstant( "JUPYTER_KERNEL_MODE_CONTROL", 1 );
BindConstant( "JUPYTER_KERNEL_MODE_EXEC", 2 );


InstallGlobalFunction( JUPYTER_LogProtocol,
function(filename)
    _KERNEL!.ProtocolLog := OutputTextFile(filename, false);
    SetPrintFormattingStatus(_KERNEL!.ProtocolLog, false);
end);

InstallGlobalFunction( JUPYTER_UnlogProtocol,
function()
    local tmp;
    # In case `CloseStream` causes messages to be printed
    tmp := _KERNEL!.ProtocolLog;
    Unbind(_KERNEL!.ProtocolLog);
    CloseStream(tmp);
end);

InstallGlobalFunction( NewJupyterKernel,
function(conf)
    local pid, address, kernel, poll, msg, status, res;

    address := Concatenation(conf.transport, "://", conf.ip, ":");
    kernel := rec( config := Immutable(conf)
                 , Username := "username"
                 , ProtocolVersion := "5.3"
                 , ZmqIdentity := HexStringUUID( RandomUUID() )
                 , SessionKey := conf.key
                 , SessionID := ""
                 , ExecutionCount := 0);


    kernel.MsgHandlers := rec( kernel_info_request := function(msg)
                                 kernel!.SessionID := msg.header.session;
                                 return JupyterMsg( kernel
                                                  , "kernel_info_reply"
                                                  , msg.header
                                                  , rec( protocol_version := kernel!.ProtocolVersion
                                                       , implementation := "GAP"
                                                       , implementation_version := GAPInfo.PackagesInfo.jupyterkernel[1].Version
                                                       , language_info := rec( name := "GAP 4"
                                                                             , version := GAPInfo.Version
                                                                             , mimetype := "text/x-gap"
                                                                             , file_extension := ".g"
                                                                             , pygments_lexer := "gap"
                                                                             , codemirror_mode := "gap"
                                                                             , nbconvert_exporter := "" )
                                                       , banner := Concatenation( "GAP Jupyter kernel ", GAPInfo.PackagesInfo.jupyterkernel[1].Version, "\n",
                                                                                  "Running on GAP ", GAPInfo.BuildVersion, "\n")
                                                       , help_links := [ rec( text := "GAP website", url := "https://www.gap-system.org/")
                                                                       , rec( text := "GAP documentation", url := "https://www.gap-system.org/Doc/doc.html")
                                                                       , rec( text := "GAP tutorial", url := "https://docs.gap-system.org/doc/chap0_mj.html")
                                                                       , rec( text := "GAP reference", url := "https://docs.gap-system.org/doc/ref/chap0_mj.html") ]
                                                       , status := "ok" )
                                                  , rec() );
                               end,

                               history_request := function(msg)
                                   msg.header.msg_type := "history_reply";
                                   msg.content := rec( history := [] );
                               end,

                               execute_request := function(msg)
                                   local publ, res, rep, r, str, data, metadata, t;

                                   JupyterMsgSend(kernel, kernel!.IOPub, JupyterMsg( kernel
                                                                       , "execute_input"
                                                                       , msg.header
                                                                       , rec( code := msg.content.code
                                                                            , execution_count := kernel!.ExecutionCount )
                                                                       , rec() ) );
                                   str := InputTextString(msg.content.code);

                                   # READ_ALL_COMMANDS was changed from 4.10. We make
                                   # JupyterKernel compatible for the time being (until
                                   # 4.10 is released at least)
                                   t := NanosecondsSinceEpoch();
                                   if CompareVersionNumbers(GAPInfo.Version, "4.10") then
                                       res := READ_ALL_COMMANDS(str, false, false, IdFunc);
                                   else
                                       res := READ_ALL_COMMANDS(str, false);
                                   fi;
                                   # This is probably supremely naughty; we overwrite GAP's
                                   # global time variable
                                   UPDATE_STAT( "time", QuoInt((NanosecondsSinceEpoch() - t), 1000000) );

                                   # Flush StdOut...
                                   Print("\c");
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
                                                    , rec( comms := rec(), status := "ok" )
                                                    , rec() );
                               end,

                               interrupt_request := function(msg)
                                   local status;
                                   # This is SIGINT
                                   status := IO_kill(pid, 2);
                                   return JupyterMsg( kernel
                                                    , "interrupt_reply"
                                                    , msg.header
                                                    , rec()
                                                    , rec() );

                               end,
                               shutdown_request := function(msg)
                                   kernel!.quitting := true;
                                   return JupyterMsg( kernel
                                                 , "shutdown_reply"
                                                 , msg.header
                                                 , rec( restart := msg.content.restart )
                                                 , rec() );
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

    kernel.HandleControlMsg := function(msg)
        local hdl_dict, f, t, reply;

        kernel!.CurrentMsg := msg.header;

        t := msg.header.msg_type;
        if IsBound(kernel!.MsgHandlers.(t)) then
            if t in [ "interrupt_request", "shutdown_request" ] then 
                JupyterMsgSend(kernel, kernel!.Control, kernel!.MsgHandlers.(t)(msg) );
            fi;
            return true;
        fi;

    end;

    _KERNEL := kernel;

    # This should happen in "Run" somehow, as currently the creation
    # of a Jupyter Kernel breaks the running GAP session, taking
    # every hope of debugging the kernel
    pid := IO_fork();
    if pid = fail then
        return fail;
    elif pid > 0 then # we are the parent and do heartbeat and control messages
        kernel.mode := JUPYTER_KERNEL_MODE_CONTROL;
        kernel.HB := ZmqRouterSocket( Concatenation(address, String(conf.hb_port) ) );
        kernel.Control := ZmqRouterSocket( Concatenation(address, String(conf.control_port) )
                                         , kernel!.ZmqIdentity);
        kernel.quitting := false;
        kernel.Loop := function()
            local topoll, poll, i, msg, res;
            topoll := [ kernel!.HB, kernel!.Control ];
            while true do
                poll := ZmqPoll( topoll, [], 5000 );
                if 1 in poll then
                    msg := ZmqReceiveList(kernel!.HB);
                    ZmqSend(kernel!.HB, msg);
                fi;
                if 2 in poll then
                    msg := JupyterMsgRecv(kernel, kernel!.Control);
                    res := kernel!.HandleControlMsg(msg);
                    if res = fail then
                        Print("failed to handle message\n");
                    fi;
                fi;
                if kernel!.quitting then
                    IO_kill(pid, 3);
                    status := IO_WaitPid(pid, true);
                    QUIT_GAP(0);
                fi;
                # Check whether child has gone away
                status := IO_WaitPid(pid, false);
                if IsRecord(status) then
                    # TODO find out what these statuses mean
                    if status.pid = pid and status.status in [ 3, 9, 15, 131 ] then
                        QUIT_GAP(0);
                    fi;
                fi;
            od;
        end;
    else
        kernel.mode  := JUPYTER_KERNEL_MODE_EXEC; # Handler
        kernel.IOPub := ZmqPublisherSocket( Concatenation(address, String(conf.iopub_port))
                                          , kernel!.ZmqIdentity);
        kernel.Shell := ZmqDealerSocket( Concatenation(address, String(conf.shell_port))
                                       , kernel!.ZmqIdentity);
        kernel.StdIn := ZmqRouterSocket( Concatenation(address, String(conf.stdin_port))
                                       , kernel!.ZmqIdentity);

        # TODO: This is of course still hacky, but better than before
        kernel!.StdOut := OutputStreamZmq(kernel, kernel!.IOPub);
        kernel!.StdErr := OutputStreamZmq(kernel, kernel!.IOPub, "stderr");
        # TODO: Hack to be able to change ERROR_OUTPUT.
        MakeReadWriteGlobal("ERROR_OUTPUT");
        ERROR_OUTPUT := kernel!.StdErr;
        MakeReadOnlyGlobal("ERROR_OUTPUT");
        OutputLogTo(kernel!.StdOut);

        # Jupyter Heartbeat and Control channel is handled by a fork'ed GAP process
        # (yes, really, its better than starting a separate thread, because it
        # doesn't need special pthread code downside is that it doesn't work on
        # cygwin, of course, but maybe we could just ExecuteProcess on windows, or
        # wait for bash on windows to become popular enoug.
        kernel.Loop := function()
            # To catch SIGINT when the kernel is idle
            while true do
                CALL_WITH_CATCH(function()
                                   local topoll, poll, i, msg, res;

                                   topoll := [ kernel!.Shell, kernel!.StdIn ];
                                   while true do
                                       poll := ZmqPoll(topoll, [], 5000);
                                       if 1 in poll then
                                           msg := JupyterMsgRecv(kernel, topoll[1]);
                                           res := kernel!.HandleShellMsg(msg);
                                           if res = fail then
                                               Print("failed to handle message\n");
                                           fi;
                                       fi;
                                       if 2 in poll then
                                           msg := ZmqReceiveList(topoll[2]);
                                       fi;
                                   od;
                               end, []);
            od;
        end;
    fi;

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
             , function(x)
                 # TODO: we should really not be doing this.
                 MakeReadWriteGlobal("HELP_SHOW_MATCHES");
                 UnbindGlobal("HELP_SHOW_MATCHES");
                 DeclareSynonym("HELP_SHOW_MATCHES", JUPYTER_HELP_SHOW_MATCHES);

                 MakeReadWriteGlobal("HELP");
                 UnbindGlobal("HELP");
                 DeclareSynonym("HELP", JUPYTER_HELP);

                 SetUserPreference("browse", "SelectHelpMatches", false);
                 SetUserPreference("Pager", "tail");
                 SetUserPreference("PagerOptions", "");
                 # This is of course complete nonsense if you're running the jupyter notebook
                 # on your local machine.
                 SetHelpViewer("jupyter_online");
                 x!.Loop();
             end);

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
