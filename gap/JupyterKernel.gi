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
BindGlobal("JUPYTER_IS_IDENT_CHAR", function(c)
    return (c >= 'a' and c <= 'z')
        or (c >= 'A' and c <= 'Z')
        or (c >= '0' and c <= '9')
        or c = '_';
end);

BindGlobal("JUPYTER_IsCompleteCode", function(code)
    local i, n, c, depth, j, ident;

    depth := 0;
    i := 1;
    n := Length(code);
    while i <= n do
        c := code[i];
        if c = '#' then
            while i <= n and code[i] <> '\n' do i := i + 1; od;
        elif c = '"' and i + 2 <= n and code{[i + 1, i + 2]} = "\"\"" then
            # Triple-quoted strings have no escapes and may contain '"'.
            j := PositionSublist(code, "\"\"\"", i + 2);
            if j = fail then
                return rec(status := "incomplete", indent := "");
            fi;
            i := j + 2;
        elif c = '"' or c = '\'' then
            i := i + 1;
            while i <= n and code[i] <> c do
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
end);


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
                 , Silent := false
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
                  errBuf, errText, savedErr, errored, ename, run,
                  code, helpres, i, j, silent, storeHistory, sendResult;

            code := msg.content.code;
            silent := msg.content.silent;
            storeHistory := msg.content.store_history and not silent;
            if storeHistory then
                kernel!.ExecutionCount := kernel!.ExecutionCount + 1;
            fi;
            kernel!.Silent := silent;
            if not silent then
                JupyterMsgSend( kernel, kernel!.IOPub
                              , JupyterMsg( kernel
                                          , "execute_input"
                                          , msg.header
                                          , rec( code := code
                                               , execution_count := kernel!.ExecutionCount )
                                          , rec() ) );
            fi;

            # As in GAP's REPL, a leading `?topic` line is a help query and
            # any following lines are code. JUPYTER_HELP itself handles the
            # `??topic` case (substring search) once we hand it the
            # post-`?` text.
            i := 1;
            while i <= Length(code) and code[i] in " \t\n\r" do
                i := i + 1;
            od;
            if i <= Length(code) and code[i] = '?' then
                j := Position(code, '\n', i);
                if j = fail then
                    j := Length(code) + 1;
                fi;
                helpres := JUPYTER_HELP(code{[i+1..j-1]});
                if not silent and IsJupyterRenderable(helpres) then
                    metadata := JupyterRenderableMetadata(helpres);
                    data := JupyterRenderableData(helpres);
                    JupyterMsgSend(kernel, kernel!.IOPub, JupyterMsg( kernel
                                                        , "execute_result"
                                                        , msg.header
                                                        , rec( data := data
                                                             , metadata := metadata
                                                             , execution_count := kernel!.ExecutionCount )
                                                        , rec() ) );
                fi;
                Print("\c");
                FlushOutputStream(kernel!.StdOut);
                FlushOutputStream(kernel!.StdErr);
                code := code{[j+1..Length(code)]};
                if ForAll(code, c -> c in " \t\n\r") then
                    kernel!.Silent := false;
                    return JupyterMsg( kernel, "execute_reply", msg.header,
                                       rec( status := "ok",
                                            execution_count := kernel!.ExecutionCount,
                                            user_expressions := rec() ),
                                       rec() );
                fi;
            fi;

            str := InputTextString(code);

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

            # Wrap the eval in CALL_WITH_CATCH so a SIGINT mid-execution
            # (sent by Jupyter when the user clicks the interrupt button —
            # see kernel.json's interrupt_mode: signal) unwinds cleanly to
            # an execute_reply with status="error" rather than killing the
            # kernel. With -T, GAP's SIGINT handler raises a normal "user
            # interrupt at ..." error that CALL_WITH_CATCH captures.
            # Called for each statement with a value not ending in ';;'.
            # GAP holds an unterminated line until "\c"; flushing first keeps
            # results in statement order and partial lines in this cell.
            sendResult := function(val)
                Print("\c");
                FlushOutputStream(kernel!.StdOut);
                if not silent then
                    rep := JupyterRender(val);
                    JupyterMsgSend(kernel, kernel!.IOPub, JupyterMsg( kernel
                        , "execute_result"
                        , msg.header
                        , rec( data := JupyterRenderableData(rep)
                             , metadata := JupyterRenderableMetadata(rep)
                             , execution_count := kernel!.ExecutionCount )
                        , rec() ) );
                fi;
            end;

            t := NanosecondsSinceEpoch();
            run := CALL_WITH_CATCH(
                READ_ALL_COMMANDS, [str, false, false, sendResult]);
            if IsBound(UPDATE_STAT) then
                UPDATE_STAT( "time", QuoInt((NanosecondsSinceEpoch() - t), 1000000) );
            fi;

            MakeReadWriteGlobal("ERROR_OUTPUT");
            ERROR_OUTPUT := savedErr;
            MakeReadOnlyGlobal("ERROR_OUTPUT");
            CloseStream(errBuf);

            Print("\c");
            FlushOutputStream(kernel!.StdOut);
            FlushOutputStream(kernel!.StdErr);

            content := rec( status := "ok"
                          , execution_count := kernel!.ExecutionCount
                          , user_expressions := rec() );
            errored := false;
            ename := "GAPError";
            if run[1] = false then
                # READ_ALL_COMMANDS itself bailed out — typically because a
                # SIGINT fired between statements before the per-statement
                # catch could be set up. errText holds GAP's error message.
                errored := true;
                if PositionSublist(errText, "user interrupt") <> fail then
                    ename := "KeyboardInterrupt";
                fi;
                res := [];
            else
                res := run[2];
            fi;
            for r in res do
                if r[1] = false then
                    errored := true;
                    if PositionSublist(errText, "user interrupt") <> fail then
                        ename := "KeyboardInterrupt";
                    fi;
                fi;
            od;

            if errored then
                if not silent then
                    # Errors during evaluation → iopub "error" message.
                    # errText carries whatever Error() printed.
                    JupyterMsgSend(kernel, kernel!.IOPub, JupyterMsg( kernel
                                                        , "error"
                                                        , msg.header
                                                        , rec( ename := ename
                                                             , evalue := errText
                                                             , traceback := [ errText ] )
                                                        , rec() ) );
                fi;
                content.status := "error";
                content.ename := ename;
                content.evalue := errText;
                content.traceback := [ errText ];
            elif not silent and Length(errText) > 0 then
                # User wrote to stderr without erroring (Print(ERROR_OUTPUT,...)).
                JupyterMsgSend(kernel, kernel!.IOPub, JupyterMsg( kernel
                                                    , "stream"
                                                    , msg.header
                                                    , rec( name := "stderr"
                                                         , text := errText )
                                                    , rec() ) );
            fi;

            kernel!.Silent := false;
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
            JupyterMsgSend( kernel, kernel!.IOPub
                          , JupyterMsg( kernel
                                      , "comm_close"
                                      , msg.header
                                      , rec( comm_id := msg.content.comm_id
                                           , data := rec() )
                                      , rec() ) );
            return fail;
        end,

        comm_info_request := function(msg)
            return JupyterMsg( kernel
                             , "comm_info_reply"
                             , msg.header
                             , rec( comms := rec(), status := "ok" )
                             , rec() );
        end,

        # No interrupt_request handler: kernel.json declares
        # interrupt_mode "signal", so Jupyter sends SIGINT directly to
        # the kernel PID. GAP's built-in SIGINT handler then surfaces
        # the interrupt as a "user interrupt at ..." error during
        # execute_request, where CALL_WITH_CATCH around READ_ALL_COMMANDS
        # converts it to a normal status="error" reply.

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

    # After a failed cell, abort the execute_requests already queued, so
    # "Run All" stops at the first error. Other requests are handled.
    kernel.AbortQueuedExecutes := function()
        local msg, reply;
        while ZmqPoll([kernel!.Shell], [], 0) <> [] do
            msg := JupyterMsgRecv(kernel, kernel!.Shell);
            if msg <> fail and msg.header.msg_type = "execute_request" then
                kernel!.CurrentMsg := msg.header;
                kernel!.SignalBusy();
                reply := JupyterMsg(kernel, "execute_reply", msg.header,
                                    rec(status := "aborted"), rec());
                reply.ids := msg.ids;
                JupyterMsgSend(kernel, kernel!.Shell, reply);
                kernel!.SignalIdle();
            elif msg <> fail then
                kernel!.HandleShellMsg(msg);
            fi;
        od;
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
            if reply <> fail then
                reply.ids := msg.ids;
                JupyterMsgSend(kernel, kernel!.Shell, reply);
                JupyterLog("    HandleShellMsg: send done\n");
            fi;
            kernel!.SignalIdle();
            JupyterLog("    HandleShellMsg: SignalIdle done\n");
            if t = "execute_request" and reply.content.status = "error"
               and not msg.content.silent
               and not (IsBound(msg.content.stop_on_error)
                        and msg.content.stop_on_error = false) then
                kernel!.AbortQueuedExecutes();
            fi;
            return true;
        else
            JupyterServerLog("unhandled shell message type: ", t);
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
            JupyterLog("    HandleControlMsg: handler returned\n");
            if reply <> fail then
                reply.ids := msg.ids;
                JupyterMsgSend(kernel, kernel!.Control, reply);
                JupyterLog("    HandleControlMsg: send done\n");
            fi;
            return true;
        fi;
        JupyterServerLog("unhandled control message type: ", t);
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

    kernel.PollOnce := function(topoll)
        local poll, raw, msg;
        poll := ZmqPoll(topoll, [], 100);
        if poll <> [] then
            JupyterLog("PollOnce: poll=", poll, "\n");
        fi;
        if 1 in poll then
            raw := ZmqReceiveList(kernel!.HB);
            ZmqSend(kernel!.HB, raw);
            JupyterLog("  HB echoed\n");
        fi;
        if 2 in poll then
            msg := JupyterMsgRecv(kernel, kernel!.Control);
            if msg <> fail then
                kernel!.HandleControlMsg(msg);
            fi;
        fi;
        if 3 in poll then
            msg := JupyterMsgRecv(kernel, kernel!.Shell);
            if msg <> fail then
                kernel!.HandleShellMsg(msg);
            fi;
        fi;
        if 4 in poll then
            ZmqReceiveList(kernel!.StdIn);
            JupyterLog("  StdIn drained\n");
        fi;
    end;

    kernel.Loop := function()
        local topoll, errText, errBuf, ok;
        JupyterLog("Loop: entering\n");
        kernel!.SignalStarting();
        JupyterLog("Loop: SignalStarting sent\n");
        topoll := [ kernel!.HB, kernel!.Control, kernel!.Shell, kernel!.StdIn ];
        while not kernel!.quitting do
            # An error outside user code must not kill the kernel. The
            # common case is SIGINT on an idle kernel, which is a no-op;
            # anything else is a kernel bug and is shown on stderr.
            errText := "";
            errBuf := OutputTextString(errText, true);
            SetPrintFormattingStatus(errBuf, false);
            MakeReadWriteGlobal("ERROR_OUTPUT");
            ERROR_OUTPUT := errBuf;
            MakeReadOnlyGlobal("ERROR_OUTPUT");
            ok := CALL_WITH_CATCH(kernel!.PollOnce, [topoll])[1];
            MakeReadWriteGlobal("ERROR_OUTPUT");
            ERROR_OUTPUT := kernel!.StdErr;
            MakeReadOnlyGlobal("ERROR_OUTPUT");
            CloseStream(errBuf);
            if not ok and PositionSublist(errText, "user interrupt") <> fail then
                JupyterLog("Loop: interrupt outside user code ignored\n");
            elif Length(errText) > 0 then
                WriteAll(kernel!.StdErr, errText);
                FlushOutputStream(kernel!.StdErr);
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
                 # Help system rerouting: SetHelpViewer points at our
                 # online viewer. We do NOT rebind the global HELP
                 # function — instead execute_request intercepts a
                 # leading `?` and dispatches to JUPYTER_HELP directly.
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
