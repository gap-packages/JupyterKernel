#!/usr/bin/env bash
# Start a JupyterLab session that knows how to run GAP.
#
# Intended for users who want to look at GAP notebooks without first
# learning Python packaging. Creates a venv on first run, installs
# this package + JupyterLab into it, then starts `jupyter lab`.
# Subsequent runs reuse the venv.
#
# The kernel finds GAP via JUPYTER_GAP_EXECUTABLE, $PATH, or the
# conventional ../../gap relative to the package source — in that
# order. If none of those work, set JUPYTER_GAP_EXECUTABLE before
# running this script.
#
# Override the venv location with $GAP_JUPYTER_VENV.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
VENV=${GAP_JUPYTER_VENV:-${XDG_CACHE_HOME:-$HOME/.cache}/gap-jupyter/venv}
SENTINEL=$VENV/.gap-jupyter-installed-version

# Use the version recorded in PackageInfo.g as a sentinel: when the
# package source bumps version, drop the venv and reinstall.
PKGVER=$(awk -F'"' '/^Version *:= *"/ {print $2; exit}' "$HERE/PackageInfo.g")
if [ -z "$PKGVER" ]; then
    echo "Cannot read the package version from $HERE/PackageInfo.g" >&2
    exit 1
fi

if [ ! -x "$VENV/bin/jupyter" ] || [ "$(cat "$SENTINEL" 2>/dev/null || true)" != "$PKGVER" ]; then
    echo "==> Setting up venv at $VENV (gap-jupyter $PKGVER)"
    mkdir -p "$(dirname "$VENV")"
    rm -rf "$VENV"
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --upgrade pip

    echo "==> Installing gap-jupyter[server] — this downloads ~200MB on first run"
    if ! "$VENV/bin/pip" install "$HERE[server]"; then
        echo
        echo "Install failed. Common causes:"
        echo "  - No network, or PyPI unreachable."
        echo "  - Python < 3.8."
        echo "Re-read the pip output above for the specific reason."
        exit 1
    fi
    echo "$PKGVER" > "$SENTINEL"
fi

# A wheel cannot find GAP relative to this source directory, so pass the
# source-layout fallback through to the installed launcher.
if [ -z "${JUPYTER_GAP_EXECUTABLE:-}" ] \
   && ! command -v gap >/dev/null 2>&1; then
    if [ -x "$HERE/../../gap" ]; then
        export JUPYTER_GAP_EXECUTABLE="$(cd "$HERE/../.." && pwd)/gap"
    else
        echo "Warning: no GAP binary found. Set JUPYTER_GAP_EXECUTABLE to" >&2
        echo "the gap binary, or put 'gap' on PATH, before opening a notebook." >&2
    fi
fi

exec "$VENV/bin/jupyter" lab "$@"
