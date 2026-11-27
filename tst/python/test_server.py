import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from urllib.error import URLError
from urllib.request import Request, urlopen


@unittest.skipIf(
    sys.platform == "cygwin",
    "JupyterLab is outside the experimental Cygwin support scope",
)
class JupyterLabTests(unittest.TestCase):
    def test_lab_serves_extension_and_launches_gap_kernel(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runtime = root / "runtime"
            config = root / "config"
            runtime.mkdir()
            config.mkdir()
            env = os.environ.copy()
            env["JUPYTER_DATA_DIR"] = str(root / "data")
            env["JUPYTER_RUNTIME_DIR"] = str(runtime)
            env["JUPYTER_CONFIG_DIR"] = str(config)
            with socket.socket() as sock:
                sock.bind(("127.0.0.1", 0))
                port = sock.getsockname()[1]

            command = [
                sys.executable,
                "-m",
                "jupyterlab",
                "--no-browser",
                "--ServerApp.ip=127.0.0.1",
                f"--ServerApp.port={port}",
                "--ServerApp.port_retries=0",
                "--ServerApp.base_url=/user/gap-test/",
                # Do not let unrelated language-server autodetection affect
                # this GAP kernel test (GitHub's Linux image includes Julia).
                "--ServerApp.jpserver_extensions",
                "jupyter_lsp=False",
                f"--ServerApp.root_dir={root}",
                "--ServerApp.shutdown_no_activity_timeout=60",
            ]
            with tempfile.TemporaryFile(mode="w+t") as log:
                server = subprocess.Popen(
                    command,
                    env=env,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    text=True,
                )
                try:
                    info = self._wait_for_server(server, runtime, log)
                    base_url = (
                        f"http://127.0.0.1:{info['port']}"
                        f"{info['base_url']}api"
                    )
                    headers = {"Authorization": f"token {info['token']}"}

                    status, page = self._request(
                        f"http://127.0.0.1:{info['port']}"
                        f"{info['base_url']}lab",
                        headers=headers,
                        parse_json=False,
                    )
                    self.assertEqual(status, 200)
                    self.assertIn(b"JupyterLab", page)
                    match = re.search(
                        rb'<script id="jupyter-config-data" '
                        rb'type="application/json">\s*(.*?)\s*</script>',
                        page,
                        re.DOTALL,
                    )
                    self.assertIsNotNone(match)
                    page_config = json.loads(match.group(1))
                    extension_names = {
                        extension["name"]
                        for extension in page_config["federated_extensions"]
                    }
                    self.assertIn("jupyterlab-gap-mode", extension_names)

                    status, kernelspecs = self._request(
                        f"{base_url}/kernelspecs", headers=headers
                    )
                    self.assertEqual(status, 200)
                    self.assertIn("gap-4", kernelspecs["kernelspecs"])

                    status, kernel = self._request(
                        f"{base_url}/kernels",
                        method="POST",
                        headers=headers,
                        body={"name": "gap-4"},
                    )
                    self.assertEqual(status, 201)

                    status, _ = self._request(
                        f"{base_url}/kernels/{kernel['id']}",
                        method="DELETE",
                        headers=headers,
                    )
                    self.assertEqual(status, 204)

                    status, _ = self._request(
                        f"{base_url}/shutdown",
                        method="POST",
                        headers=headers,
                    )
                    self.assertEqual(status, 200)
                    server.wait(timeout=15)
                    self.assertEqual(server.returncode, 0, self._read_log(log))
                finally:
                    if server.poll() is None:
                        server.terminate()
                        try:
                            server.wait(timeout=10)
                        except subprocess.TimeoutExpired:
                            server.kill()
                            server.wait()

    def _wait_for_server(self, server, runtime, log):
        deadline = time.monotonic() + 30
        last_error = None
        while time.monotonic() < deadline:
            if server.poll() is not None:
                self.fail(
                    f"Jupyter Server exited with {server.returncode}:\n"
                    f"{self._read_log(log)}"
                )
            for info_file in runtime.glob("jpserver-*.json"):
                try:
                    info = json.loads(info_file.read_text())
                    headers = {
                        "Authorization": f"token {info['token']}"
                    }
                    self._request(
                        f"http://127.0.0.1:{info['port']}"
                        f"{info['base_url']}api/status",
                        headers=headers,
                    )
                    return info
                except (KeyError, json.JSONDecodeError, URLError) as error:
                    last_error = error
            time.sleep(0.1)
        self.fail(
            f"Jupyter Server did not start within 30 seconds "
            f"({last_error!r}):\n{self._read_log(log)}"
        )

    def _request(
        self, url, method="GET", headers=None, body=None, parse_json=True
    ):
        data = None if body is None else json.dumps(body).encode()
        request = Request(url, data=data, method=method, headers=headers or {})
        if data is not None:
            request.add_header("Content-Type", "application/json")
        with urlopen(request, timeout=5) as response:
            content = response.read()
            if not parse_json:
                return response.status, content
            return response.status, json.loads(content) if content else None

    def _read_log(self, log):
        log.flush()
        log.seek(0)
        return log.read()
