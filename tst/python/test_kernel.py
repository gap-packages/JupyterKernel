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
import zmq
from jupyter_client.session import Session


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
    complete_code_samples = ["1+1;", 'Print("hi\\n");', "[1,2,3];",
                             "c := '\"';", "c := '(';", 's := """a"b""";']
    incomplete_code_samples = [
        "f := function(x)",
        "[1, 2, 3",
        "if true then 1",
        'x := "unclosed',
        "x := '#'; y := (1",
        's := """multi\nline',
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

    def test_interrupt_idle(self):
        """Interrupting an idle kernel is a no-op: the kernel and its
        state survive, and nothing is printed."""
        content, _ = self._execute_and_collect("idle_state := 17;")
        self.assertEqual(content["status"], "ok")
        self.flush_channels()
        self.km.interrupt_kernel()
        time.sleep(1.0)
        self.assertTrue(self.km.is_alive())
        with self.assertRaises(Empty):
            self.kc.get_iopub_msg(timeout=0.5)
        content, iopub = self._execute_and_collect("idle_state;")
        self.assertEqual(content["status"], "ok")
        results = [m for m in iopub if m["msg_type"] == "execute_result"]
        self.assertEqual(results[0]["content"]["data"]["text/plain"], "17")

    def test_comm_open_on_control(self):
        """comm_open has no reply; on Control this once killed the kernel."""
        self.flush_channels()
        msg = self.kc.session.msg("comm_open", content={
            "comm_id": "control-comm", "target_name": "t", "data": {}})
        self.kc.control_channel.send(msg)
        close = self.kc.get_iopub_msg(timeout=10)
        self.assertEqual(close["msg_type"], "comm_close")
        with self.assertRaises(Empty):
            self.kc.get_iopub_msg(timeout=0.5)
        self.assertTrue(self.km.is_alive())

    def test_unhandled_message_prints_nothing(self):
        """Unknown message types are logged on the server, not shown
        in the notebook."""
        self.flush_channels()
        self.kc.shell_channel.send(self.kc.session.msg(
            "comm_msg", content={"comm_id": "x", "data": {}}))
        self.kc.control_channel.send(self.kc.session.msg("usage_request"))
        deadline = time.time() + 2
        while time.time() < deadline:
            try:
                msg = self.kc.get_iopub_msg(timeout=0.5)
            except Empty:
                continue
            self.assertNotEqual(msg["msg_type"], "stream", msg["content"])

    def test_complete_after_non_ascii(self):
        """cursor_pos counts code points, not UTF-8 bytes."""
        code = "# \u03b1\u03b2\nx := Gro"
        self.kc.complete(code, len(code))
        reply = self.get_non_kernel_info_reply(timeout=10)
        content = reply["content"]
        self.assertIn("Group", content["matches"])
        self.assertEqual(code[content["cursor_start"]:content["cursor_end"]], "Gro")

    def test_inspect_reply_is_bounded(self):
        self._execute_and_collect("insp_G := SymmetricGroup(7);; AsList(insp_G);;")
        self.kc.inspect("insp_G", 6)
        content = self.get_non_kernel_info_reply(timeout=30)["content"]
        self.assertTrue(content["found"])
        self.assertLess(len(content["data"]["text/plain"]), 10000)

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

    def test_bad_messages_are_dropped_silently(self):
        """A wrongly signed or malformed message must be ignored: no reply,
        nothing on IOPub (which once leaked the expected signature), and
        the kernel stays up."""
        info = self.km.get_connection_info()
        ctx = zmq.Context.instance()
        shell = ctx.socket(zmq.DEALER)
        shell.connect(f"tcp://{info['ip']}:{info['shell_port']}")
        try:
            forger = Session(key=b"not-the-key")
            forged = forger.msg("execute_request", content={
                "code": "forged_marker := 1;", "silent": False,
                "store_history": True, "user_expressions": {},
                "allow_stdin": False, "stop_on_error": True})
            self.flush_channels()
            shell.send_multipart(forger.serialize(forged))
            shell.send_multipart([b"garbage"])
            self.assertFalse(shell.poll(2000), "kernel replied to a bad message")
        finally:
            shell.close(linger=0)
        with self.assertRaises(Empty):
            self.kc.get_iopub_msg(timeout=0.5)
        self.assertTrue(self.km.is_alive())

        content, iopub = self._execute_and_collect('IsBoundGlobal("forged_marker");')
        self.assertEqual(content["status"], "ok")
        results = [m for m in iopub if m["msg_type"] == "execute_result"]
        self.assertEqual(results[0]["content"]["data"]["text/plain"], "false")

    def test_unsupported_comm_is_closed(self):
        self.flush_channels()
        request = self.kc.session.msg(
            "comm_open",
            content={
                "comm_id": "unsupported-test-comm",
                "target_name": "unsupported-test-target",
                "data": {},
            },
        )
        self.kc.shell_channel.send(request)

        close = None
        deadline = time.time() + 10
        while time.time() < deadline:
            try:
                msg = self.kc.get_iopub_msg(timeout=2)
            except Empty:
                continue
            if msg["parent_header"].get("msg_id") != request["header"]["msg_id"]:
                continue
            if msg["msg_type"] == "comm_close":
                close = msg
            if (msg["msg_type"] == "status"
                    and msg["content"]["execution_state"] == "idle"):
                break

        self.assertIsNotNone(close, "unsupported comm_open did not produce comm_close")
        self.assertEqual(close["content"]["comm_id"], "unsupported-test-comm")
        with self.assertRaises(Empty):
            self.kc.get_shell_msg(timeout=0.2)

    def _execute_and_collect(self, code, timeout=30, **execute_kwargs):
        """Send `code` and return (reply_content, iopub_msgs).

        Drain iopub until we see status="idle" for our msg_id (the spec
        guarantee that no further iopub messages will follow for this
        execution), then read the matching execute_reply on shell.
        Reading shell first races: the kernel sends iopub before the
        reply, but the client's two channels are independent threads
        and can deliver out of order."""
        self.flush_channels()
        msg_id = self.kc.execute(code, **execute_kwargs)
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

    def test_execution_count_is_per_request(self):
        content, iopub = self._execute_and_collect("1; 2;")
        self.assertEqual(content["status"], "ok")
        count = content["execution_count"]
        execute_inputs = [m for m in iopub if m["msg_type"] == "execute_input"]
        results = [m for m in iopub if m["msg_type"] == "execute_result"]
        self.assertEqual(len(execute_inputs), 1)
        self.assertEqual(len(results), 2)
        self.assertEqual(execute_inputs[0]["content"]["execution_count"], count)
        self.assertTrue(
            all(m["content"]["execution_count"] == count for m in results)
        )

        next_content, _ = self._execute_and_collect("3;")
        self.assertEqual(next_content["execution_count"], count + 1)

    def test_silent_execution_has_no_output_or_history(self):
        before, _ = self._execute_and_collect("", silent=True)
        content, iopub = self._execute_and_collect(
            'silent_value := 41; Print("hidden\\n"); silent_value + 1;',
            silent=True,
        )
        self.assertEqual(content["status"], "ok")
        self.assertEqual(content["execution_count"], before["execution_count"])
        self.assertEqual(
            [
                m
                for m in iopub
                if m["msg_type"] not in {"status"}
            ],
            [],
        )

        visible, visible_iopub = self._execute_and_collect("silent_value;")
        self.assertEqual(visible["execution_count"], before["execution_count"] + 1)
        results = [m for m in visible_iopub if m["msg_type"] == "execute_result"]
        self.assertEqual(results[0]["content"]["data"]["text/plain"], "41")

    def test_silent_execution_still_reports_errors(self):
        before, _ = self._execute_and_collect("", silent=True)
        content, iopub = self._execute_and_collect("1/0;", silent=True)
        self.assertEqual(content["status"], "error")
        self.assertEqual(content["execution_count"], before["execution_count"])
        self.assertTrue(content["traceback"])
        self.assertEqual(
            [m for m in iopub if m["msg_type"] not in {"status"}],
            [],
        )

    def test_store_history_false_does_not_increment_count(self):
        before, _ = self._execute_and_collect("", silent=True)
        content, iopub = self._execute_and_collect(
            "21 * 2;", store_history=False
        )
        self.assertEqual(content["status"], "ok")
        self.assertEqual(content["execution_count"], before["execution_count"])
        execute_inputs = [m for m in iopub if m["msg_type"] == "execute_input"]
        results = [m for m in iopub if m["msg_type"] == "execute_result"]
        self.assertEqual(execute_inputs[0]["content"]["execution_count"], before["execution_count"])
        self.assertEqual(results[0]["content"]["execution_count"], before["execution_count"])

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

    def test_undefined_variable_does_not_hang_kernel(self):
        content, _ = self._execute_and_collect(
            "DefinitelyUndefinedJupyterKernelVariable"
        )
        self.assertEqual(content["status"], "error")

        content, iopub = self._execute_and_collect("6 * 7;")
        self.assertEqual(content["status"], "ok")
        results = [m for m in iopub if m["msg_type"] == "execute_result"]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["content"]["data"]["text/plain"], "42")

    def test_enumerator_has_compact_display(self):
        content, iopub = self._execute_and_collect(
            "Enumerator(SymmetricGroup(99));"
        )
        self.assertEqual(content["status"], "ok")
        results = [m for m in iopub if m["msg_type"] == "execute_result"]
        self.assertEqual(len(results), 1)
        self.assertEqual(
            results[0]["content"]["data"]["text/plain"],
            "<enumerator of perm group>",
        )

    def test_restart_after_error(self):
        content, _ = self._execute_and_collect("1/0;")
        self.assertEqual(content["status"], "error")

        started = time.monotonic()
        self.km.restart_kernel(now=False)
        self.kc.wait_for_ready(timeout=15)
        self.assertLess(time.monotonic() - started, 15)

        content, iopub = self._execute_and_collect("6 * 7;")
        self.assertEqual(content["status"], "ok")
        results = [m for m in iopub if m["msg_type"] == "execute_result"]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["content"]["data"]["text/plain"], "42")

    def _stream_and_results(self, code):
        content, iopub = self._execute_and_collect(code)
        self.assertEqual(content["status"], "ok")
        return [m["content"]["text"] if m["msg_type"] == "stream"
                else m["content"]["data"]["text/plain"]
                for m in iopub if m["msg_type"] in ("stream", "execute_result")]

    def test_unterminated_output_stays_in_its_cell(self):
        self.assertEqual(self._stream_and_results('Print("no newline"); 42;'),
                         ["no newline", "42"])
        self.assertEqual(self._stream_and_results('Print("next\\n");'),
                         ["next\n"])

    def _queue_and_reply_statuses(self, cells, **execute_kwargs):
        self.flush_channels()
        ids = [self.kc.execute(c, **execute_kwargs) for c in cells]
        statuses = {}
        deadline = time.time() + 30
        while len(statuses) < len(ids) and time.time() < deadline:
            try:
                reply = self.kc.get_shell_msg(timeout=2)
            except Empty:
                continue
            if reply["parent_header"].get("msg_id") in ids:
                statuses[reply["parent_header"]["msg_id"]] = reply["content"]["status"]
        return [statuses.get(i) for i in ids]

    def test_error_aborts_queued_cells(self):
        """Run All must stop at the first failing cell."""
        self.assertEqual(
            self._queue_and_reply_statuses(["1/0;", "aborted_marker := 1;"]),
            ["error", "aborted"])
        self.assertEqual(
            self._queue_and_reply_statuses(["1/0;", "kept_marker := 1;"],
                                           stop_on_error=False),
            ["error", "ok"])
        out = self._stream_and_results(
            'IsBound(aborted_marker); IsBound(kept_marker);')
        self.assertEqual(out, ["false", "true"])

    def test_results_in_statement_order(self):
        self.assertEqual(
            self._stream_and_results('Print("a\\n"); 1; Print("b"); 2; 3;; 4;'),
            ["a\n", "1", "b", "2", "4"])

    def test_long_lines_are_not_wrapped(self):
        self.assertEqual(
            self._stream_and_results("Print(ListWithIdenticalEntries(100, 'x'), \"\\n\");"),
            ["x" * 100 + "\n"])

    def test_result_follows_output_after_flood(self):
        """Output batched after a flood must still precede the result."""
        out = self._stream_and_results(
            'for i in [1..300] do Print(i, "\\n"); od; Print("tail\\n"); 42;')
        self.assertEqual(out[-1], "42")
        self.assertTrue(out[-2].endswith("tail\n"))

    def test_long_output_stress(self):
        """100000 lines must all arrive, followed by status idle. ZMQ PUB
        drops messages beyond 1000 queued, so one message per line lost
        output and the idle status."""
        n = 100000
        content, iopub = self._execute_and_collect(
            f'for i in [1..{n}] do Print(i, "\\n"); od;', timeout=60
        )
        self.assertEqual(content["status"], "ok")
        all_text = "".join(
            m["content"]["text"] for m in iopub
            if m["msg_type"] == "stream" and m["content"]["name"] == "stdout"
        )
        self.assertEqual(all_text, "".join(f"{i}\n" for i in range(1, n + 1)))

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

    def test_help_line_then_code(self):
        """Only the first line of a `?` cell is the help topic; the rest
        runs as code, as in GAP's REPL."""
        content, _ = self._execute_and_collect("?Group\nhelp_then_code := 5;")
        self.assertEqual(content["status"], "ok")
        self.assertEqual(self._stream_and_results("help_then_code;"), ["5"])

    def test_stream_batching(self):
        """100 byte-sized prints with no newlines must NOT produce 100
        separate stream messages — GAP and the kernel buffer stdout until a
        newline."""
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
