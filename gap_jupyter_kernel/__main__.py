"""Cross-platform launcher for the GAP Jupyter kernel.

Replaces the legacy ``bin/jupyter-kernel-gap`` shell script so that the kernel
also starts on Windows. Resolves the GAP binary in this order:

1. ``$JUPYTER_GAP_EXECUTABLE``
2. ``$GAP``
3. ``shutil.which("gap")``

then ``execvp``s ``gap -q -T --alwaystrace -c '<bootstrap>'`` with the
connection file path passed through from Jupyter.

We use ``os.execvp`` rather than ``subprocess.call`` so this Python process
is replaced by GAP at the same PID. Jupyter records the PID returned by
``Popen`` and, with ``interrupt_mode: "signal"``, sends SIGINT to that
PID when the user hits the interrupt button. If we kept Python around as
a parent, the signal would land on Python and never reach GAP.
"""

import os
import shutil
import sys


def _find_gap() -> str:
    for env in ("JUPYTER_GAP_EXECUTABLE", "GAP"):
        path = os.environ.get(env)
        if path:
            return path
    found = shutil.which("gap")
    if found:
        return found
    sys.exit(
        "gap-jupyter: could not find a GAP executable. "
        "Set JUPYTER_GAP_EXECUTABLE to the gap binary, or put `gap` on PATH."
    )


def _bootstrap_script(connection_file: str) -> str:
    # The connection file path is passed verbatim into a GAP string literal.
    # GAP string syntax escapes backslash and double-quote with backslash.
    escaped = connection_file.replace("\\", "\\\\").replace('"', '\\"')
    return (
        f'LoadPackage("JupyterKernel");'
        f'JUPYTER_KernelStart_GAP("{escaped}");'
        f'QUIT_GAP(0);'
    )


def main() -> int:
    if len(sys.argv) != 2:
        sys.exit("usage: python -m gap_jupyter_kernel <connection_file>")
    gap = _find_gap()
    script = _bootstrap_script(sys.argv[1])
    try:
        os.execvp(gap, [gap, "-q", "-T", "--alwaystrace", "-c", script])
    except OSError as e:
        sys.exit(f"gap-jupyter: failed to exec {gap!r}: {e}")


if __name__ == "__main__":
    sys.exit(main())
