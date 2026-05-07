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
