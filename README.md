[![CI](https://github.com/gap-packages/JupyterKernel/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/gap-packages/JupyterKernel/actions?query=workflow%3ACI+branch%3Amaster)
[![Code Coverage](https://codecov.io/github/gap-packages/JupyterKernel/coverage.svg?branch=master&token=)](https://codecov.io/gh/gap-packages/JupyterKernel)
[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/gap-packages/JupyterKernel/HEAD)
# The JupyterKernel GAP package 

This package implements the [Jupyter](https://www.jupyter.org) protocol in GAP.

## Installation

This package targets Jupyter Notebook 7 / JupyterLab 4 and Python 3.8+.
Classic Notebook (5/6) is no longer supported.

### Dependencies

JupyterKernel itself does not need compilation, but it depends on several
other GAP packages that do. On Debian/Ubuntu the system-level prerequisites
are:

- `libzmq3-dev`
- `m4`

The required GAP packages are listed in `PackageInfo.g` (`io`, `json`,
`uuid`, `ZeroMQInterface`, `crypting`, `GAPDoc`).

### Installing the kernel

#### Quick start (no Jupyter installed)

From the package directory:

    ./start-jupyter.sh

That creates a venv under `~/.cache/gap-jupyter/venv`, installs the
kernel + JupyterLab into it, then opens a JupyterLab session.
Subsequent runs reuse the venv. Requires Python 3.8+ and Node.js 18+.
The kernel auto-discovers GAP via `JUPYTER_GAP_EXECUTABLE`, `GAP`,
`$PATH`, or the conventional `<gap-root>/gap` next to the `pkg/`
directory — in that order.

#### Adding the kernel to your existing Jupyter

From the package directory:

    pip install .

That single command:

- installs the `gap_jupyter_kernel` Python launcher,
- registers the kernel spec under `share/jupyter/kernels/gap-4`,
- registers the bundled JupyterLab extension under
  `share/jupyter/labextensions/jupyterlab-gap-mode` for syntax
  highlighting.

JupyterLab and Notebook 7 discover both at startup; `GAP 4` shows up in
the kernel selector and GAP cells get highlighted automatically.

If GAP is not on your `PATH`, set `JUPYTER_GAP_EXECUTABLE` to the absolute
path of the `gap` binary; the launcher reads it on every start.

Building from source requires Node.js 18+ (only contributors need it; end
users install from a wheel that already contains the prebuilt JS).

### Running

    jupyter notebook
    # or
    jupyter lab

then pick `GAP 4` as the kernel.

### Syntax highlighting

GAP cells are highlighted by a CodeMirror 6 mode shipped as a prebuilt
JupyterLab extension (`jupyterlab-gap-mode`). It is installed automatically
by `pip install .` and discovered by JupyterLab and Notebook 7 without any
extra step. Verify with:

    jupyter labextension list

The mode tokenises GAP keywords (`function`/`end`, `if`/`fi`, `for`/`od`
…), comments (`#`-to-end-of-line), strings, character literals, numbers,
and the standard operators (`:=`, `..`, `->`, `<>`).

Source for the mode lives in `src/`; rebuild with:

    npm install
    jupyter labextension build .

### Interrupting a running computation

The notebook's interrupt button sends SIGINT directly to the GAP process
(`interrupt_mode: "signal"` in `kernel.json`). GAP's own interrupt handler
turns that into a normal "user interrupt" error, which the kernel converts
to an `execute_reply` with `status: "error"` and `ename: "KeyboardInterrupt"`.

Caveat: GAP only checks for an interrupt at GAP-level statement boundaries.
Tight C-level loops — e.g. some `Factors(BigInteger)` calls — will not be
interruptible until they return to the interpreter.

### Troubleshooting

If the kernel does not start, first check that the package loads in plain
GAP:

    gap -c 'LoadPackage("JupyterKernel"); QUIT;'

If that prints `fail`, follow the diagnostic instructions GAP prints to find
which dependency is missing. If it prints `true` but Jupyter still cannot
start the kernel, check that `python -m gap_jupyter_kernel /tmp/dummy.json`
runs (it will error out parsing the dummy file, but the launcher itself
should be reachable).

## Documentation

Information and documentation can be found in the manual, available
as PDF `doc/manual.pdf` or as HTML `doc/chap0_mj.html`, or on the package
homepage at

  <https://gap-packages.github.io/JupyterKernel/>

## Bug reports and feature requests

Please submit bug reports and feature requests via our GitHub issue tracker:

  <https://github.com/gap-packages/JupyterKernel/issues>


# License

JupyterKernel is free software; you can redistribute it and/or modify it under
the terms of the BSD 3-clause license.

For details see the files COPYRIGHT.md and LICENSE.

# Acknowledgement

<table class="none">
<tr>
<td>
  <img src="https://opendreamkit.org/public/logos/Flag_of_Europe.svg" width="128">
</td>
<td>
  This infrastructure is part of a project that has received funding from the
  European Union's Horizon 2020 research and innovation programme under grant
  agreement No 676541.
</td>
</tr>
</table>

