#
# JupyterKernel: Jupyter kernel using ZeroMQ
#
# Implementations
#

# Global handle on the active kernel, used by JUPYTER_LogProtocol /
# JUPYTER_UnlogProtocol to enable runtime protocol tracing from a Jupyter
# cell.
_KERNEL := "";


InstallGlobalFunction( JUPYTER_LogProtocol,
function(filename)
    _KERNEL!.ProtocolLog := OutputTextFile(filename, false);
    SetPrintFormattingStatus(_KERNEL!.ProtocolLog, false);
end);

InstallGlobalFunction( JUPYTER_UnlogProtocol,
function()
    local tmp;
    tmp := _KERNEL!.ProtocolLog;
    Unbind(_KERNEL!.ProtocolLog);
    CloseStream(tmp);
end);


# Heuristic for the Jupyter is_complete protocol: count brackets and GAP
# block keywords (function/end, if/fi, for|while/od, repeat/until), treating
# the contents of strings and comments as opaque. Returns "incomplete" if
# any opener lacks its closer (so the cell needs more input to parse),
# otherwise "complete". We do not try to distinguish syntactically invalid
# input from incomplete input — the evaluator will report syntax errors
# more precisely than the parser would.
JUPYTER_IS_IDENT_CHAR := function(c)
    return (c >= 'a' and c <= 'z')
        or (c >= 'A' and c <= 'Z')
        or (c >= '0' and c <= '9')
        or c = '_';
end;

JUPYTER_IsCompleteCode := function(code)
    local i, n, c, depth, j, ident;

    depth := 0;
    i := 1;
    n := Length(code);
    while i <= n do
        c := code[i];
        if c = '#' then
            while i <= n and code[i] <> '\n' do i := i + 1; od;
        elif c = '"' then
            i := i + 1;
            while i <= n and code[i] <> '"' do
                if code[i] = '\\' and i < n then i := i + 1; fi;
                i := i + 1;
            od;
            if i > n then
                return rec(status := "incomplete", indent := "");
            fi;
        elif c in "([{" then
            depth := depth + 1;
        elif c in ")]}" then
            depth := depth - 1;
        elif JUPYTER_IS_IDENT_CHAR(c) and not (c >= '0' and c <= '9') then
            j := i;
            while j <= n and JUPYTER_IS_IDENT_CHAR(code[j]) do j := j + 1; od;
            ident := code{[i..j-1]};
            # Block keyword must be at a word boundary on both sides — the
            # JUPYTER_IS_IDENT_CHAR loop above guarantees this for the right.
            if ident in [ "function", "if", "for", "while", "repeat" ] then
                depth := depth + 1;
            elif ident in [ "end", "fi", "od", "until" ] then
                depth := depth - 1;
            fi;
            i := j;
            continue;
        fi;
        i := i + 1;
    od;
    if depth > 0 then
        return rec(status := "incomplete", indent := "");
    fi;
    return rec(status := "complete");
end;


InstallGlobalFunction( NewJupyterKernel,
function(conf)
    local address, kernel;

    Assert(0, IsBound(CRYPTING_SHA256_HMAC),
           "crypting package is missing CRYPTING_SHA256_HMAC; refusing to start");

    address := Concatenation(conf.transport, "://", conf.ip, ":");
    kernel := rec( config := Immutable(conf)
                 , Username := "username"
                 , ProtocolVersion := "5.3"
                 , ZmqIdentity := HexStringUUID( RandomUUID() )
                 , SessionKey := conf.key
                 , SessionID := ""
                 , ExecutionCount := 0
                 , quitting := false );

    kernel.MsgHandlers := rec(
        kernel_info_request := function(msg)
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

        execute_request := function(msg)
            local publ, res, r, rep, str, data, metadata, t, content,
                  errBuf, errText, savedErr, errored;

            JupyterMsgSend( kernel, kernel!.IOPub
                          , JupyterMsg( kernel
                                      , "execute_input"
                                      , msg.header
                                      , rec( code := msg.content.code
                                           , execution_count := kernel!.ExecutionCount + 1 )
                                      , rec() ) );
            str := InputTextString(msg.content.code);

            # Swap ERROR_OUTPUT to a buffer for the duration of the
            # evaluation, so we can tell apart "the user's code errored"
            # (→ Jupyter "error" iopub message + ename/evalue/traceback
            # in the reply) from "the user wrote to stderr deliberately"
            # (→ Jupyter "stream" stderr message).
            errText := "";
            errBuf := OutputTextString(errText, true);
            SetPrintFormattingStatus(errBuf, false);
            MakeReadWriteGlobal("ERROR_OUTPUT");
            savedErr := ERROR_OUTPUT;
            ERROR_OUTPUT := errBuf;
            MakeReadOnlyGlobal("ERROR_OUTPUT");

            t := NanosecondsSinceEpoch();
            res := READ_ALL_COMMANDS(str, false, false, IdFunc);
            if IsBound(UPDATE_STAT) then
                UPDATE_STAT( "time", QuoInt((NanosecondsSinceEpoch() - t), 1000000) );
            fi;

            MakeReadWriteGlobal("ERROR_OUTPUT");
            ERROR_OUTPUT := savedErr;
            MakeReadOnlyGlobal("ERROR_OUTPUT");
            CloseStream(errBuf);

            content := rec( status := "ok"
                          , execution_count := kernel!.ExecutionCount + 1 );
            errored := false;
            for r in res do
                if r[1] = true then
                    kernel!.ExecutionCount := kernel!.ExecutionCount + 1;
                    if IsBound(r[2]) and r[3] = false then
                        rep := JupyterRender(r[2]);
                        metadata := JupyterRenderableMetadata(rep);
                        data := JupyterRenderableData(rep);
                        JupyterMsgSend(kernel, kernel!.IOPub, JupyterMsg( kernel
                                                            , "execute_result"
                                                            , msg.header
                                                            , rec( data := data
                                                                 , metadata := metadata
                                                                 , execution_count := kernel!.ExecutionCount )
                                                            , rec() ) );
                    fi;
                else
                    errored := true;
                fi;
            od;

            FlushOutputStream(kernel!.StdOut);
            FlushOutputStream(kernel!.StdErr);

            if errored then
                # Errors during evaluation → iopub "error" message + status
                # in reply. errText carries whatever Error() printed.
                JupyterMsgSend(kernel, kernel!.IOPub, JupyterMsg( kernel
                                                    , "error"
                                                    , msg.header
                                                    , rec( ename := "GAPError"
                                                         , evalue := errText
                                                         , traceback := [ errText ] )
                                                    , rec() ) );
                content.status := "error";
                content.ename := "GAPError";
                content.evalue := errText;
                content.traceback := [ errText ];
            elif Length(errText) > 0 then
                # User wrote to stderr without erroring (Print(ERROR_OUTPUT,...)).
                JupyterMsgSend(kernel, kernel!.IOPub, JupyterMsg( kernel
                                                    , "stream"
                                                    , msg.header
                                                    , rec( name := "stderr"
                                                         , text := errText )
                                                    , rec() ) );
            fi;

            content.execution_count := kernel!.ExecutionCount;
            return JupyterMsg( kernel, "execute_reply", msg.header, content, rec() );
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
                             , JUPYTER_IsCompleteCode(msg.content.code)
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

        # Without IO_fork the kernel cannot interrupt itself between polls.
        # We accept the request and acknowledge; PR 7 will install a SIGINT
        # handler and switch kernel.json to interrupt_mode: signal.
        interrupt_request := function(msg)
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
        local m;
        JupyterLog("      SignalBusy: building msg\n");
        m := JupyterMsg( kernel
                       , "status"
                       , kernel!.CurrentMsg
                       , rec( execution_state := "busy" )
                       , rec() );
        JupyterLog("      SignalBusy: msg built, sending\n");
        JupyterMsgSend( kernel, kernel!.IOPub, m );
        JupyterLog("      SignalBusy: sent\n");
    end;

    kernel.SignalIdle := function()
        JupyterMsgSend( kernel, kernel!.IOPub
                      , JupyterMsg( kernel
                                  , "status"
                                  , kernel!.CurrentMsg
                                  , rec( execution_state := "idle" )
                                  , rec() ) );
    end;

    kernel.SignalStarting := function()
        JupyterMsgSend( kernel, kernel!.IOPub
                      , JupyterMsg( kernel
                                  , "status"
                                  , rec()
                                  , rec( execution_state := "starting" )
                                  , rec() ) );
    end;

    kernel.HandleShellMsg := function(msg)
        local t, reply;
        kernel!.CurrentMsg := msg.header;
        JupyterLog("    HandleShellMsg: type=", msg.header.msg_type,
                 " ids-len=", Length(msg.ids), "\n");
        kernel!.SignalBusy();
        JupyterLog("    HandleShellMsg: SignalBusy done\n");
        t := msg.header.msg_type;
        if IsBound(kernel!.MsgHandlers.(t)) then
            reply := kernel!.MsgHandlers.(t)(msg);
            JupyterLog("    HandleShellMsg: handler returned\n");
            reply.ids := msg.ids;
            JupyterMsgSend(kernel, kernel!.Shell, reply);
            JupyterLog("    HandleShellMsg: send done\n");
            kernel!.SignalIdle();
            JupyterLog("    HandleShellMsg: SignalIdle done\n");
            return true;
        else
            Print("unhandled shell message type: ", t, "\n");
            kernel!.SignalIdle();
            return fail;
        fi;
    end;

    # Control is a parallel of Shell for messages the frontend must be able
    # to deliver while Shell is busy: interrupt_request, shutdown_request,
    # debug_request, and (since JupyterLab 4 / jupyter_server) liveness
    # probes via kernel_info_request. Anything we have a handler for is
    # answered here. Unlike Shell, we do NOT publish busy/idle status on
    # Control replies — that would falsely interrupt the Shell execution
    # stream the frontend tracks for cell results.
    kernel.HandleControlMsg := function(msg)
        local t, reply;
        kernel!.CurrentMsg := msg.header;
        t := msg.header.msg_type;
        JupyterLog("    HandleControlMsg: type=", t,
                 " ids-len=", Length(msg.ids), "\n");
        if IsBound(kernel!.MsgHandlers.(t)) then
            reply := kernel!.MsgHandlers.(t)(msg);
            JupyterLog("    HandleControlMsg: handler returned, sending\n");
            reply.ids := msg.ids;
            JupyterMsgSend(kernel, kernel!.Control, reply);
            JupyterLog("    HandleControlMsg: send done\n");
            return true;
        fi;
        Print("unhandled control message type: ", t, "\n");
        return fail;
    end;

    # Socket binding is done in BindSockets(), called by Run(). Tests can
    # construct a kernel record without opening ports.
    kernel.BindSockets := function()
        # Bind sockets in this order: IOPub first so subscribers can attach
        # before any status message is published (ZMQ PUB has slow-joiner
        # semantics — anything sent before the subscriber is wired is lost).
        kernel!.IOPub   := ZmqPublisherSocket( Concatenation(address, String(conf.iopub_port))
                                             , kernel!.ZmqIdentity);
        # Per Jupyter wire spec, Shell is ROUTER on the kernel side. The
        # envelope (peer identity) frames are captured at recv time by
        # JupyterMsgDecode and prepended at send time by JupyterMsgEncode.
        kernel!.Shell   := ZmqRouterSocket(    Concatenation(address, String(conf.shell_port))
                                             , kernel!.ZmqIdentity);
        kernel!.StdIn   := ZmqRouterSocket(    Concatenation(address, String(conf.stdin_port))
                                             , kernel!.ZmqIdentity);
        kernel!.Control := ZmqRouterSocket(    Concatenation(address, String(conf.control_port))
                                             , kernel!.ZmqIdentity);
        kernel!.HB      := ZmqRouterSocket(    Concatenation(address, String(conf.hb_port)));

        kernel!.StdOut := OutputStreamZmq(kernel, kernel!.IOPub);
        kernel!.StdErr := OutputStreamZmq(kernel, kernel!.IOPub, "stderr");

        MakeReadWriteGlobal("ERROR_OUTPUT");
        ERROR_OUTPUT := kernel!.StdErr;
        MakeReadOnlyGlobal("ERROR_OUTPUT");
        OutputLogTo(kernel!.StdOut);
    end;

    kernel.Loop := function()
        local topoll, poll, raw, status, iter;
        JupyterLog("Loop: entering\n");
        kernel!.SignalStarting();
        JupyterLog("Loop: SignalStarting sent\n");
        topoll := [ kernel!.HB, kernel!.Control, kernel!.Shell, kernel!.StdIn ];
        iter := 0;
        while not kernel!.quitting do
            iter := iter + 1;
            poll := ZmqPoll(topoll, [], 100);
            if poll <> [] then
                JupyterLog("Loop iter ", iter, ": poll=", poll, "\n");
            fi;
            if 1 in poll then
                raw := ZmqReceiveList(kernel!.HB);
                ZmqSend(kernel!.HB, raw);
                JupyterLog("  HB echoed\n");
            fi;
            if 2 in poll then
                status := CALL_WITH_CATCH(function()
                    kernel!.HandleControlMsg(JupyterMsgRecv(kernel, kernel!.Control));
                end, []);
                JupyterLog("  Control: status[1]=", status[1], "\n");
                if status[1] = false then
                    JupyterLog("    Control error: ", status[2], "\n");
                fi;
            fi;
            if 3 in poll then
                status := CALL_WITH_CATCH(function()
                    kernel!.HandleShellMsg(JupyterMsgRecv(kernel, kernel!.Shell));
                end, []);
                JupyterLog("  Shell: status[1]=", status[1], "\n");
                if status[1] = false then
                    JupyterLog("    Shell error: ", status[2], "\n");
                fi;
            fi;
            if 4 in poll then
                ZmqReceiveList(kernel!.StdIn);
                JupyterLog("  StdIn drained\n");
            fi;
        od;
        JupyterLog("Loop: exited because quitting=true\n");
    end;

    _KERNEL := kernel;
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
                 JupyterLog("Run: entered, GAPInfo.Version=",
                            GAPInfo.Version, "\n");
                 # Help system rerouting: SetHelpViewer points at our online
                 # viewer; we no longer rebind the global HELP function (a
                 # PR 6 follow-up will route ?topic through execute_request).
                 SetUserPreference("browse", "SelectHelpMatches", false);
                 SetUserPreference("Pager", "tail");
                 SetUserPreference("PagerOptions", "");
                 SetHelpViewer("jupyter_online");
                 JupyterLog("Run: about to BindSockets\n");
                 x!.BindSockets();
                 JupyterLog("Run: about to Loop\n");
                 x!.Loop();
                 JupyterLog("Run: Loop returned, QUIT_GAP\n");
                 QUIT_GAP(0);
             end);

InstallGlobalFunction( JUPYTER_KernelStart_HPC,
function(conf)
    Error("HPC-GAP is not supported with this code.");
    QUIT_GAP(0);
end);

InstallGlobalFunction( JUPYTER_KernelStart_GAP,
function(configfile)
    local instream, conf, kernel;
    instream := InputTextFile(configfile);
    conf := JsonStreamToGap(instream);
    CloseStream(instream);
    kernel := NewJupyterKernel(conf);
    Run(kernel);
end);
