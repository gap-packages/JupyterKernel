# Tests for OutputStreamZmq batching: print is buffered until newline
# or until the threshold is hit, and a single FlushOutputStream call drains
# the buffer to one stream message rather than one-per-byte.
#
# We don't need a real ZMQ socket: we monkey-patch JupyterMsgSend to record
# invocations into a list.

gap> START_TEST("JupyterKernel: stream.tst");

# Build a fake stream that bypasses the IsZmqSocket check by constructing
# directly via Objectify, with a string in place of a socket.
gap> kernel := Objectify(NewType(NewFamily("FakeKern3"), IsObject and IsComponentObjectRep), \
>      rec( ZmqIdentity := "id", Username := "u", SessionID := "s",
>           SessionKey := "k", ProtocolVersion := "5.3" ));;
gap> stream := Objectify(OutputStreamZmqType, \
>      rec( kernel := kernel, socket := "fakesock", format := false,
>           streamname := "stdout", buffer := "" ));;

# Capture every JupyterMsgSend call.
gap> sends := [];;
gap> origSend := JupyterMsgSend;;
gap> MakeReadWriteGlobal("JupyterMsgSend");;
gap> JupyterMsgSend := function(k, sock, msg) Add(sends, msg.content.text); end;;

# Before any newline: a partial line accumulates, no send happens.
gap> WriteAll(stream, "hello ");
true
gap> Length(sends);
0
gap> stream!.buffer;
"hello "

# Newline triggers a flush — exactly one send for the whole line.
gap> WriteAll(stream, "world\n");
true
gap> Length(sends);
1
gap> sends[1];
"hello world\n"
gap> stream!.buffer;
""

# 100 small Print()-style writes with no newlines should produce zero
# sends until we explicitly flush.
gap> sends := [];;
gap> for i in [1..100] do WriteAll(stream, "x"); od;
gap> Length(sends);
0
gap> Length(stream!.buffer);
100
gap> FlushOutputStream(stream);
gap> Length(sends);
1
gap> sends[1] = ListWithIdenticalEntries(100, 'x');
true

# WriteByte: buffer and flush on byte = '\n'.
gap> sends := [];;
gap> WriteByte(stream, INT_CHAR('a'));
true
gap> Length(sends);
0
gap> WriteByte(stream, INT_CHAR('\n'));
true
gap> Length(sends);
1
gap> sends[1];
"a\n"

# Threshold flush: when buffer reaches JUPYTER_STREAM_FLUSH_THRESHOLD it auto-flushes.
gap> sends := [];;
gap> bigstring := ListWithIdenticalEntries(JUPYTER_STREAM_FLUSH_THRESHOLD + 1, 'q');;
gap> WriteAll(stream, bigstring);
true
gap> Length(sends);
1

# FlushOutputStream on an empty buffer is a no-op.
gap> sends := [];;
gap> FlushOutputStream(stream);
gap> Length(sends);
0

# Restore the real JupyterMsgSend.
gap> JupyterMsgSend := origSend;;
gap> MakeReadOnlyGlobal("JupyterMsgSend");;
gap> STOP_TEST("stream.tst", 1);
