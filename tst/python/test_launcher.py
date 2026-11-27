import os
import json
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from gap_jupyter_kernel.__main__ import _bootstrap_script, _find_gap, _start_heartbeat


class LauncherTests(unittest.TestCase):
    def test_heartbeat_exits_when_lifetime_pipe_closes(self):
        with tempfile.TemporaryDirectory() as directory:
            with socket.socket() as port:
                port.bind(("127.0.0.1", 0))
                number = port.getsockname()[1]
            connection = Path(directory) / "connection.json"
            connection.write_text(json.dumps({
                "transport": "tcp", "ip": "127.0.0.1", "hb_port": number}))
            descriptor, helper = _start_heartbeat(str(connection))
            self.assertIsNone(helper.poll())
            os.close(descriptor)
            helper.wait(timeout=5)
            self.assertEqual(helper.returncode, 0)

    def test_startup_error_exits_nonzero(self):
        with tempfile.TemporaryDirectory() as directory, socket.socket() as port:
            port.bind(("127.0.0.1", 0))
            port.listen()
            connection = Path(directory) / "connection.json"
            connection.write_text(json.dumps({
                "transport": "tcp", "ip": "127.0.0.1", "key": "",
                "hb_port": port.getsockname()[1], "shell_port": port.getsockname()[1],
                "iopub_port": port.getsockname()[1], "control_port": port.getsockname()[1],
                "stdin_port": port.getsockname()[1]}))
            # Drive GAP directly so this tests the bootstrap catch, rather
            # than the launcher's heartbeat-port check.
            result = subprocess.run(
                [_find_gap(), "-q", "-T", "-c", _bootstrap_script(str(connection))],
                capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 1)

    @patch.dict(os.environ, {"GAP": "gap --quitonbreak"}, clear=True)
    @patch("gap_jupyter_kernel.__main__.shutil.which", return_value="/usr/bin/gap")
    def test_gap_command_environment_does_not_shadow_path(self, which):
        self.assertEqual(_find_gap(), "/usr/bin/gap")
        which.assert_called_once_with("gap")

    @patch.dict(
        os.environ,
        {"JUPYTER_GAP_EXECUTABLE": "/opt/gap/bin/gap"},
        clear=True,
    )
    @patch("gap_jupyter_kernel.__main__.shutil.which")
    def test_explicit_executable_override_takes_precedence(self, which):
        self.assertEqual(_find_gap(), "/opt/gap/bin/gap")
        which.assert_not_called()

    @patch("gap_jupyter_kernel.__main__.REQUIRED_VERSION", ">= 999")
    def test_unloadable_package_exits_nonzero(self):
        proc = subprocess.run(
            [_find_gap(), "-q", "-T", "--alwaystrace", "-c",
             _bootstrap_script("/nonexistent.json")],
            stdin=subprocess.DEVNULL, capture_output=True, text=True,
            timeout=120)
        self.assertEqual(proc.returncode, 1, proc.stderr)
        self.assertIn("cannot load JupyterKernel >= 999", proc.stderr)
