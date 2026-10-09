# Tests message handlers without binding ZMQ sockets. NewJupyterKernel now
# splits construction from socket binding (BindSockets is called by Run);
# this test only exercises the handler closures.

gap> START_TEST("JupyterKernel: protocol.tst");
gap> conf := rec( transport := "tcp", ip := "127.0.0.1", key := "test-key",
>                 hb_port := 5555, control_port := 1111, iopub_port := 2222,
>                 shell_port := 3333, stdin_port := 4444 );;
gap> kernel := NewJupyterKernel(conf);;
gap> kernel!.ProtocolVersion;
"5.3"
gap> kernel!.SessionKey;
"test-key"
gap> kernel!.ExecutionCount;
0
gap> kernel!.quitting;
false
gap> reply := kernel!.MsgHandlers.kernel_info_request( \
>     rec( header := rec( session := "session-id" ) ) );;
gap> reply.header.msg_type;
"kernel_info_reply"
gap> reply.content.protocol_version;
"5.3"
gap> reply.content.implementation;
"GAP"
gap> reply.content.language_info.name;
"GAP 4"
gap> kernel!.SessionID;
"session-id"
gap> ic := kernel!.MsgHandlers.is_complete_request( \
>     rec( header := rec(), content := rec( code := "1+1;" ) ) );;
gap> ic.content.status;
"complete"
gap> ic := kernel!.MsgHandlers.is_complete_request( \
>     rec( header := rec(), content := rec( code := "f := function(x)" ) ) );;
gap> ic.content.status;
"incomplete"
gap> ic := kernel!.MsgHandlers.is_complete_request( \
>     rec( header := rec(), content := rec( code := "[1,2,3" ) ) );;
gap> ic.content.status;
"incomplete"
gap> ic := kernel!.MsgHandlers.is_complete_request( \
>     rec( header := rec(), content := rec( code := "1; # ( unclosed in comment" ) ) );;
gap> ic.content.status;
"complete"
gap> ic := kernel!.MsgHandlers.is_complete_request( \
>     rec( header := rec(), content := rec( code := "x := \"hello" ) ) );;
gap> ic.content.status;
"incomplete"
gap> kernel!.MsgHandlers.shutdown_request( \
>     rec( header := rec(), content := rec( restart := false ) ) );;
gap> kernel!.quitting;
true
gap> STOP_TEST("protocol.tst", 1);
