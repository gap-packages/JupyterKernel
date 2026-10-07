# Tests for JupyterMsg encode/decode and HMAC computation.
#
# Golden HMAC value pinned: a regression in the encoder will change this.

gap> START_TEST("JupyterKernel: msg.tst");

# JUPYTER_ComputeHMAC: golden value over the four canonical strings.
gap> JUPYTER_ComputeHMAC("test-session-key", "{\"a\":1}", "{}", "{}", "{}");
"8e753a98782301eb001a7f44e45e1bf7c44de691ed9d6837c57449ea66b82cd4"
gap> JUPYTER_ComputeHMAC("", "{\"a\":1}", "{}", "{}", "{}");
""

# Build a minimal kernel-like record we can pass to encode/decode.
gap> kernel := Objectify(NewType(NewFamily("FakeKern"), IsObject and IsComponentObjectRep), \
>      rec( ZmqIdentity := "abcd"
>         , Username := "user"
>         , SessionID := "sess"
>         , SessionKey := "test-session-key"
>         , ProtocolVersion := "5.3" ));;

# Encode a message and check it has 7 ZMQ frames and a non-empty HMAC.
gap> msg := JupyterMsg(kernel, "kernel_info_request", rec(), rec(foo := 1), rec());;
gap> raw := JupyterMsgEncode(kernel, msg);;
gap> Length(raw);
7
gap> raw[2];
"<IDS|MSG>"
gap> Length(raw[3]) = 64;  # SHA-256 hex digest
true

# Decode round-trips: same content, same metadata.
gap> back := JupyterMsgDecode(kernel, raw);;
gap> back.content.foo;
1
gap> back.header.msg_type;
"kernel_info_request"

# A wrong key or malformed frames give fail, and nothing reveals the
# expected signature.
gap> wrong := Objectify(NewType(NewFamily("FakeKern2"), IsObject and IsComponentObjectRep), \
>      rec( SessionKey := "different-key" ));;
gap> JupyterMsgDecode(wrong, raw);
fail
gap> JupyterMsgDecode(kernel, ["garbage"]);
fail
gap> JupyterMsgDecode(kernel, []);
fail
gap> JupyterMsgDecode(kernel, raw{[1 .. 6]});
fail
gap> JupyterMsgDecode(kernel, Concatenation(["id1", "id2"], raw{[2 .. 7]})).ids;
[ "id1", "id2" ]

# An empty connection-file key disables authentication. Such messages carry
# an empty signature rather than an HMAC computed with an empty key.
gap> kernel!.SessionKey := "";; msg.key := "";;
gap> raw := JupyterMsgEncode(kernel, msg);;
gap> raw[3];
""
gap> JupyterMsgDecode(kernel, raw).content.foo;
1
gap> STOP_TEST("msg.tst", 1);
