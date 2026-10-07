"""Cross-platform launcher for the GAP Jupyter kernel.

Replaces the legacy ``bin/jupyter-kernel-gap`` shell script so that the kernel
also starts on Windows. Resolves the GAP binary in this order:

1. ``$JUPYTER_GAP_EXECUTABLE``
2. ``shutil.which("gap")``
3. ``../../gap`` relative to the package source — picks up the GAP
   binary at ``<gap-root>/gap`` when this package is installed in the
   conventional ``<gap-root>/pkg/jupyterkernel`` layout. Only fires
   for editable installs where ``__file__`` still resolves to the
   package source.

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
from pathlib import Path

REQUIRED_VERSION = ">= 2.0"


def _find_gap() -> str:
    path = os.environ.get("JUPYTER_GAP_EXECUTABLE")
    if path:
        return path
    found = shutil.which("gap")
    if found:
        return found
    # __main__.py / gap_jupyter_kernel / pkg-root / pkg / <gap-root>
    candidate = Path(__file__).resolve().parents[3] / "gap"
    if candidate.is_file() and os.access(candidate, os.X_OK):
        return str(candidate)
    sys.exit(
        "gap-jupyter: could not find a GAP executable. "
        "Set JUPYTER_GAP_EXECUTABLE to the gap binary, or put `gap` on PATH."
    )


def _bootstrap_script(connection_file: str) -> str:
    # The connection file path is passed verbatim into a GAP string literal.
    # GAP string syntax escapes backslash and double-quote with backslash.
    escaped = connection_file.replace("\\", "\\\\").replace('"', '\\"')
    # GAP's own pkg/ may hold a JupyterKernel 1.x, which this launcher
    # cannot drive.
    return f"""
if LoadPackage("JupyterKernel", "{REQUIRED_VERSION}") <> true then
    err := OutputTextFile("*errout*", true);
    SetPrintFormattingStatus(err, false);
    PrintTo(err, "gap-jupyter: cannot load JupyterKernel {REQUIRED_VERSION}\\n");
    for r in PackageInfo("JupyterKernel") do
        PrintTo(err, "  found ", r.Version, " in ", r.InstallationPath, "\\n");
    od;
    PrintTo(err, "To see why, run in GAP: SetInfoLevel(InfoPackageLoading, 4);",
                 " LoadPackage(\\"JupyterKernel\\");\\n");
    QUIT_GAP(1);
fi;
JUPYTER_KernelStart_GAP("{escaped}");
QUIT_GAP(0);
"""


def _redirect_stdin_to_devnull() -> None:
    """Replace fd 0 with /dev/null before exec'ing GAP.

    Jupyter spawns kernels with a stdin pipe that nothing ever writes
    to. If GAP code calls `InputFromUser` (or anything else that reads
    from `*stdin*`), the read blocks indefinitely and the kernel
    appears to hang. Pointing fd 0 at /dev/null instead causes those
    reads to return EOF, which GAP surfaces as a clear error rather
    than a deadlock.

    Real interactive input via the Jupyter `input_request` protocol is
    a separate piece of work. Once that lands, the GAP-side helper
    will read from the StdIn ZMQ socket; this redirect stays as the
    safety net for `*stdin*` reads outside that helper.
    """
    try:
        devnull = os.open(os.devnull, os.O_RDONLY)
    except OSError:
        return
    try:
        os.dup2(devnull, 0)
    finally:
        if devnull != 0:
            try:
                os.close(devnull)
            except OSError:
                pass


def main() -> int:
    if len(sys.argv) != 2:
        sys.exit("usage: python -m gap_jupyter_kernel <connection_file>")
    gap = _find_gap()
    script = _bootstrap_script(sys.argv[1])
    _redirect_stdin_to_devnull()
    # The kernel copies GAP's stdout to the notebook with OutputLogTo;
    # the original would echo every cell's output to the server's terminal.
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 1)
    os.close(devnull)
    try:
        os.execvp(gap, [gap, "-q", "-T", "--alwaystrace", "-c", script])
    except OSError as e:
        sys.exit(f"gap-jupyter: failed to exec {gap!r}: {e}")


if __name__ == "__main__":
    sys.exit(main())
