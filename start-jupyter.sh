#!/usr/bin/env bash
# Start a JupyterLab session that knows how to run GAP.
#
# Intended for users who want to look at GAP notebooks without first
# learning Python packaging. Creates a venv on first run, installs
# this package + JupyterLab into it, then starts `jupyter lab`.
# Subsequent runs reuse the venv.
#
# The kernel finds GAP via JUPYTER_GAP_EXECUTABLE, GAP, $PATH, or the
# conventional ../../gap relative to the package source — in that
# order. If none of those work, set JUPYTER_GAP_EXECUTABLE before
# running this script.
#
# Override the venv location with $GAP_JUPYTER_VENV.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
VENV=${GAP_JUPYTER_VENV:-${XDG_CACHE_HOME:-$HOME/.cache}/gap-jupyter/venv}
SENTINEL=$VENV/.gap-jupyter-installed-version

# Use the version recorded in pyproject.toml as a sentinel: when the
# package source bumps version, drop the venv and reinstall.
PKGVER=$(awk -F'"' '/^version *= *"/ {print $2; exit}' "$HERE/pyproject.toml")

if [ ! -x "$VENV/bin/jupyter" ] || [ "$(cat "$SENTINEL" 2>/dev/null || true)" != "$PKGVER" ]; then
    echo "==> Setting up venv at $VENV (gap-jupyter $PKGVER)"
    mkdir -p "$(dirname "$VENV")"
    rm -rf "$VENV"
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --upgrade pip

    echo "==> Installing gap-jupyter[server] — this needs Node.js (>= 18)"
    echo "    and downloads ~200MB on first run"
    if ! "$VENV/bin/pip" install "$HERE[server]"; then
        echo
        echo "Install failed. Common causes:"
        echo "  - Node.js (>= 18) not installed; the labextension build needs it."
        echo "  - No network, or PyPI / npm registry unreachable."
        echo "  - Python < 3.8."
        echo "Re-read the pip output above for the specific reason."
        exit 1
    fi
    echo "$PKGVER" > "$SENTINEL"
fi

# Sanity-check that the kernel can find GAP. We don't want jupyter
# to come up only for the kernel to die on first cell execution.
if [ -z "${JUPYTER_GAP_EXECUTABLE:-}" ] && [ -z "${GAP:-}" ] \
   && ! command -v gap >/dev/null 2>&1 \
   && [ ! -x "$HERE/../../gap" ]; then
    echo "Warning: no GAP binary found. Set JUPYTER_GAP_EXECUTABLE to" >&2
    echo "the gap binary, or put 'gap' on PATH, before opening a notebook." >&2
fi

exec "$VENV/bin/jupyter" lab "$@"
