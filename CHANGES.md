# Changes

## 2.0.0 (2026-05-08)

A near-total rewrite. The 1.x series stopped working with Jupyter Notebook 7
and JupyterLab 4. This release targets those frontends and drops support
for the classic Notebook (5/6) and the bundled CodeMirror 5 nbextension.

### Breaking

- **Install procedure has changed.** `pip install .` now installs both
  the kernel spec and the JupyterLab extension via a `pyproject.toml`
  / `hatch_jupyter_builder` build pipeline. The old
  `bin/jupyter-kernel-gap` shell script, the `etc/gap-mode/` nbextension,
  and `setup.py` are gone.
- **Cross-platform launcher.** The kernel is now started by a Python
  launcher (`python -m gap_jupyter_kernel <connection_file>`), which
  `os.execvp`s into GAP. Works on Windows under Cygwin where the bash
  launcher used to fail (issue #140).
- **Single-process kernel.** The 1.x design `IO_fork`'d a worker
  child; this release runs everything in one process. The fork-side
  IOPub status `starting` was missing, which is what caused the
  Notebook 7 "Nudge" warnings (issue #138).
- **Real interrupts.** `interrupt_mode` is now `signal`. The notebook
  interrupt button delivers SIGINT to the kernel PID; GAP's built-in
  handler unwinds it as a `KeyboardInterrupt`-style error rather than
  hanging or restarting the kernel.

### New

- **JupyterLab extension** for GAP syntax highlighting, packaged as a
  prebuilt labextension (`jupyterlab-gap-mode`). End users get
  highlighting automatically with `pip install`; only contributors
  need Node.
- **End-to-end protocol tests** via `jupyter_kernel_test` in
  `tst/python/`, exercised in CI on Linux + macOS.
- **CI on Linux, macOS, and Windows** (Windows via Cygwin and the
  `gap-actions/setup-cygwin` action with `libzmq-devel`).
- **`is_complete_request` heuristic** that tracks GAP block keywords
  (`function`/`end`, `if`/`fi`, `for`/`od`, `while`/`od`,
  `repeat`/`until`) plus brackets, so multi-line cells in the JupyterLab
  console behave properly.
- **Stream batching.** Output is buffered and flushed on newlines or
  at 4096 bytes, so a tight `Print` loop produces a handful of stream
  messages instead of one per byte.
- **Tightened wire protocol.** ZMQ envelopes are now threaded through
  request-reply pairs (Shell, Control, StdIn are all ROUTER on the
  kernel side per spec). HMAC mismatches `Error` rather than warning
  silently, and the encoder asserts the four canonical message slots
  are present.

### Fixes

- Notebook-7 / JupyterLab-4 liveness probe (`kernel_info_request` on
  Control) is now answered.
- Output streams are flushed before the `execute_reply` so trailing
  output isn't dropped or reordered.
- Error replies include `ename`, `evalue`, and `traceback` per the
  spec; `1/0;` no longer drops the message client-side.

### Known limitations / out of scope

- **Interactive input.** GAP cells that call `InputFromUser` see EOF
  immediately rather than hanging the kernel; full
  `input_request`/`input_reply` support is a TODO.
- **ipywidgets / Comms.** Real Comm support is a separate piece of
  work; the kernel acknowledges `comm_open` / `comm_info_request` but
  does not implement widget state.
- **HPC-GAP.** Not supported (issue #108).
- **Tight C-level loops** are not interruptible by SIGINT until they
  return to the GAP interpreter.
