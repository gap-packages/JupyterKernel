"""End-to-end protocol tests for the GAP Jupyter kernel.

Drives a real kernel over ZMQ via jupyter_kernel_test; covers the
behaviours that the GAP-side .tst files cannot reach (slow-joiner safety,
shell/iopub interleaving, batching of stream output, multi-line input,
shutdown, etc.).
"""

import time
import unittest
from queue import Empty

import jupyter_kernel_test


KERNEL_NAME = "gap-4"


class GapKernelTests(jupyter_kernel_test.KernelTests):

    kernel_name = KERNEL_NAME
    language_name = "GAP 4"
    file_extension = ".g"

    # Framework's test_execute_stdout looks for "hello, world" in a stdout
    # stream message.
    code_hello_world = 'Print("hello, world\\n");'

    # Framework's test_execute_stderr looks for any stderr stream message.
    # GAP's *errout* is the OS-level stderr fd (not captured by the
    # kernel); ERROR_OUTPUT is a script-level global which the kernel
    # rewires per execute_request to a capture buffer. Writing there
    # produces a stderr stream message.
    code_stderr = 'PrintTo(ERROR_OUTPUT, "boom\\n");'

    # Framework's test_execute_result checks data["text/plain"] exactly.
    code_execute_result = [
        {"code": "1+1;", "result": "2"},
        {"code": "Length([1,2,3]);", "result": "3"},
    ]

    # Framework's test_error checks status=error and exactly one iopub
    # message of type "error".
    code_generate_error = "1/0;"

    # Framework's test_inspect sends an inspect_request for this string
    # and checks status=ok and found=true.
    code_inspect_sample = "Group"

    # Framework's test_is_complete checks each sample maps to the right status.
    complete_code_samples = ["1+1;", 'Print("hi\\n");', "[1,2,3];"]
    incomplete_code_samples = [
        "f := function(x)",
        "[1, 2, 3",
        "if true then 1",
        'x := "unclosed',
    ]

    # We deliberately skip the framework's set-equality test_completion
    # (its assertEqual would only pass if our matches were exactly the
    # claimed set — but IDENTS_BOUND_GVARS returns dozens of "Gro*"
    # identifiers). The custom test below uses assertIn instead.
    completion_samples = []

    def test_completion_contains_expected(self):
        """Custom completion check: 'Gro' must produce 'Group' as one of
        the matches (not necessarily the only one)."""
        self.flush_channels()
        self.kc.complete("Gro", 3)
        deadline = time.time() + 10
        while time.time() < deadline:
            try:
                msg = self.kc.get_shell_msg(timeout=2)
            except Empty:
                continue
            if msg["msg_type"] == "complete_reply":
                matches = msg["content"]["matches"]
                self.assertIn("Group", matches)
                self.assertEqual(msg["content"]["status"], "ok")
                return
        self.fail("no complete_reply received")

    def test_implementation_is_gap(self):
        self.flush_channels()
        self.kc.kernel_info()
        msg = self.kc.get_shell_msg(timeout=10)
        info = msg["content"]
        self.assertEqual(info["status"], "ok")
        self.assertEqual(info["implementation"], "GAP")
        self.assertTrue(info["banner"], "banner must be non-empty")
        self.assertEqual(info["language_info"]["name"], "GAP 4")

    def test_interrupt(self):
        """Sending an interrupt mid-execute_request must unwind to an
        execute_reply with status="error" — not kill the kernel.

        Requires interrupt_mode="signal" (in kernel.json) AND that the
        kernel process is the same PID Jupyter spawned (i.e. the Python
        launcher must os.execvp into GAP rather than wrapping it as a
        child)."""
        self.flush_channels()
        # Long-running loop that returns to the GAP interpreter often
        # enough for SIGINT to be checked. A tight C-level loop would
        # not be interruptible — that's a GAP-level limitation.
        msg_id = self.kc.execute("while true do od;")
        # Give the kernel a moment to pick the message up.
        time.sleep(1.0)
        self.km.interrupt_kernel()
        deadline = time.time() + 30
        while time.time() < deadline:
            try:
                msg = self.kc.get_shell_msg(timeout=2)
            except Empty:
                continue
            if msg["msg_type"] != "execute_reply":
                continue
            if msg["parent_header"].get("msg_id") != msg_id:
                continue
            self.assertEqual(msg["content"]["status"], "error")
            # Don't pin the exact ename; GAP wording may vary across
            # versions. Just confirm the error mentions interrupt.
            evalue = msg["content"].get("evalue", "")
            self.assertIn("interrupt", evalue.lower(),
                          f"expected interrupt-flavoured error, got {evalue!r}")
            return
        self.fail("no execute_reply received within 30s of interrupt_kernel()")

    def test_kernel_info_on_control(self):
        """JupyterLab 4 / jupyter_server sends kernel_info_request on the
        Control channel as a liveness probe. If we don't reply there, Lab
        believes the kernel is dead and restarts it in a tight loop. The
        Shell handler isn't enough — Control must dispatch it too."""
        self.flush_channels()
        msg = self.kc.session.msg("kernel_info_request")
        self.kc.control_channel.send(msg)
        deadline = time.time() + 10
        while time.time() < deadline:
            try:
                reply = self.kc.get_control_msg(timeout=2)
            except Empty:
                continue
            if reply["msg_type"] == "kernel_info_reply":
                self.assertEqual(reply["content"]["status"], "ok")
                self.assertEqual(reply["content"]["implementation"], "GAP")
                return
        self.fail("no kernel_info_reply on control channel")

    def _execute_and_collect(self, code, timeout=30):
        """Send `code` and return (reply_content, iopub_msgs).

        Drain iopub until we see status="idle" for our msg_id (the spec
        guarantee that no further iopub messages will follow for this
        execution), then read the matching execute_reply on shell.
        Reading shell first races: the kernel sends iopub before the
        reply, but the client's two channels are independent threads
        and can deliver out of order."""
        self.flush_channels()
        msg_id = self.kc.execute(code)
        iopub = []
        deadline = time.time() + timeout
        # Phase 1: drain iopub for our msg_id until idle.
        while time.time() < deadline:
            try:
                msg = self.kc.get_iopub_msg(timeout=2)
            except Empty:
                continue
            if msg["parent_header"].get("msg_id") != msg_id:
                continue
            iopub.append(msg)
            if (msg["msg_type"] == "status"
                    and msg["content"]["execution_state"] == "idle"):
                break
        else:
            self.fail(f"no idle status received within {timeout}s")
        # Phase 2: pick up the execute_reply on shell.
        reply = None
        while time.time() < deadline:
            try:
                rmsg = self.kc.get_shell_msg(timeout=2)
            except Empty:
                continue
            if (rmsg["msg_type"] == "execute_reply"
                    and rmsg["parent_header"].get("msg_id") == msg_id):
                reply = rmsg
                break
        self.assertIsNotNone(reply, "no execute_reply received")
        return reply["content"], iopub

    def test_multiline_function_definition(self):
        """A function definition split across newlines must execute as
        one statement — not be parsed as several."""
        code = (
            "double := function(x)\n"
            "    return 2 * x;\n"
            "end;;\n"
            "double(21);"
        )
        content, iopub = self._execute_and_collect(code)
        self.assertEqual(content["status"], "ok")
        results = [m for m in iopub if m["msg_type"] == "execute_result"]
        self.assertEqual(len(results), 1, f"expected one result, got {results}")
        self.assertEqual(results[0]["content"]["data"]["text/plain"], "42")

    def test_unicode_string(self):
        """GAP can hold arbitrary bytes in strings; UTF-8 round-trip
        through stdout must reach the client unaltered. We embed the α
        directly in the source — GAP strings are byte arrays, so the
        UTF-8 bytes (0xCE 0xB1) are stored as-is and Print emits them
        verbatim."""
        content, iopub = self._execute_and_collect(
            'Print("α\\n");'
        )
        self.assertEqual(content["status"], "ok")
        streams = [m for m in iopub
                   if m["msg_type"] == "stream"
                   and m["content"]["name"] == "stdout"]
        all_text = "".join(s["content"]["text"] for s in streams)
        self.assertIn("α", all_text,
                      f"expected α in stdout, got {all_text!r}")

    def test_comments_only_cell(self):
        """A cell containing nothing but comments must succeed with no
        execute_result, no error."""
        content, iopub = self._execute_and_collect(
            "# just a comment\n"
            "# and another\n"
        )
        self.assertEqual(content["status"], "ok")
        results = [m for m in iopub if m["msg_type"] == "execute_result"]
        self.assertEqual(results, [])
        errors = [m for m in iopub if m["msg_type"] == "error"]
        self.assertEqual(errors, [])

    def test_runtime_vs_parse_error(self):
        """A runtime error (1/0) and a parse error (`1 +`) both must
        come back as status="error" with a non-empty traceback."""
        for code in ["1/0;", "1 +"]:
            with self.subTest(code=code):
                content, iopub = self._execute_and_collect(code)
                self.assertEqual(content["status"], "error",
                                 f"expected error for {code!r}")
                self.assertTrue(content.get("traceback"),
                                f"expected non-empty traceback for {code!r}")

    def test_long_output_stress(self):
        """A burst of newline-separated output lines must arrive intact
        and finish in reasonable time. Catches regressions in the
        per-flush batching loop and in the iopub stream encoder."""
        content, iopub = self._execute_and_collect(
            'for i in [1..2000] do Print(i, "\\n"); od;', timeout=60
        )
        self.assertEqual(content["status"], "ok")
        all_text = "".join(
            m["content"]["text"] for m in iopub
            if m["msg_type"] == "stream" and m["content"]["name"] == "stdout"
        )
        # First and last lines made it.
        self.assertTrue(all_text.startswith("1\n"),
                        f"missing leading line, head={all_text[:40]!r}")
        self.assertTrue(all_text.rstrip().endswith("\n2000")
                        or all_text.endswith("2000\n"),
                        f"missing trailing line, tail={all_text[-40:]!r}")
        # Right total count.
        self.assertEqual(all_text.count("\n"), 2000)

    def test_help_magic(self):
        """A cell starting with `?` must dispatch to the help path
        rather than be parsed as GAP syntax (where leading `?` is a
        syntax error). We don't pin the rendered output: GAP's
        help-system flow depends on which books loaded, and the
        useful cross-version invariant is just `status == "ok"`."""
        content, _ = self._execute_and_collect("?Group")
        self.assertEqual(content["status"], "ok")
        # And a non-existent topic also shouldn't error — should be
        # an "ok" status with a "no match"-style message somewhere.
        content, _ = self._execute_and_collect("?ThisIsNotAGapSymbol")
        self.assertEqual(content["status"], "ok")

    def test_stream_batching(self):
        """Regression test for output batching (PR 3).

        100 byte-sized prints with no newlines must NOT produce 100
        separate stream messages — the kernel buffers and flushes on
        newline / threshold."""
        self.flush_channels()
        self.kc.execute('for i in [1..100] do Print("x"); od; Print("\\n");')
        stream_msgs = 0
        deadline = time.time() + 30
        while time.time() < deadline:
            try:
                msg = self.kc.get_iopub_msg(timeout=2)
            except Empty:
                continue
            t = msg["msg_type"]
            if t == "stream" and msg["content"]["name"] == "stdout":
                stream_msgs += 1
            elif t == "status" and msg["content"]["execution_state"] == "idle":
                break
        self.assertGreaterEqual(stream_msgs, 1, "expected at least one stdout stream message")
        self.assertLess(
            stream_msgs, 10,
            f"expected stream batching, got {stream_msgs} stream messages",
        )
