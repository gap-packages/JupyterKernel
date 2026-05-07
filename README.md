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

From the package directory:

    pip install .
    jupyter kernelspec install --user etc/jupyter --name gap-4

`pip install .` installs the `gap_jupyter_kernel` Python launcher.
`jupyter kernelspec install` registers the kernel with Jupyter so that
`GAP 4` shows up in the kernel selector.

If GAP is not on your `PATH`, set `JUPYTER_GAP_EXECUTABLE` to the absolute
path of the `gap` binary; the launcher reads it on every start.

### Running

    jupyter notebook
    # or
    jupyter lab

then pick `GAP 4` as the kernel.

### Syntax highlighting

This release does not bundle a JupyterLab/Notebook 7 syntax-highlighting
extension. Code is shown as plain text. A future release may ship a
labextension; contributions welcome.

### Interrupting a running computation

This release accepts interrupt requests from the notebook UI but does not
act on them while a computation is running — the kernel is single-process
and cannot poll for interrupts mid-`READ_ALL_COMMANDS`. Long-running cells
must be allowed to finish or the kernel restarted. A follow-up release
will switch to signal-mode interrupts.

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

