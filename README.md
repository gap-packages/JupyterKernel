[![Build Status](https://github.com/gap-packages/JupyterKernel/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/gap-packages/JupyterKernel/actions?query=workflow%3ACI+branch%3Amaster)
[![Code Coverage](https://codecov.io/github/gap-packages/JupyterKernel/coverage.svg?branch=master&token=)](https://codecov.io/gh/gap-packages/JupyterKernel)
[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/gap-packages/JupyterKernel/HEAD)
# The JupyterKernel GAP package 

This package implements the [Jupyter](https://www.jupyter.org) protocol in GAP.

## Installation

**Note: If you need to reinstall this package, you will also need to re-run
`pip3 install .`, and re-add the Jupyter kernel to your PATH**

### Dependencies and installation


Download and unpack the corresponding archive from the GAP website at

  <https://www.gap-system.org/Releases/>
  
For Windows installations, it is recommended to utilise an installation of
Windows Subsystem for Linux (WSL) as this makes the installation process
much more streamlined. JupyterKernel does not require compilation, 
but it depends on several other GAP packages, of which several have to be built
and require the following dependencies:

- libzmq3-dev
- m4

### Jupyter Setup

Jupyter can be installed using the following:

    pip3 install notebook
            
in your terminal (or for Windows, under WSL's terminal). While other methods
do work for installing python, this method has been tested to work well with
JupyterKernel.

Note that a Python version >= 3.5 is required. Once that is done, the GAP Jupyter
kernel must be registered with Jupyter, by running the following command 
in the `pkg/JupyterKernel` directory of your GAP installation:

    pip3 install .

or for your user only:

    pip3 install . --user

### Adding JupyterKernel to your PATH

If GAP is not in your PATH, then you have to set the environment variable
`JUPYTER_GAP_EXECUTABLE` to point to your GAP executable for Jupyter to
be able to execute GAP, and the script `jupyter-kernel-gap` that is
distributed with this package in the directory `bin/` needs to be in
your path.

This can be done through symlinking:

    sudo ln -s <GAP-installation-directory>/gap gap
  
    sudo ln -s <GAP-installation-directory>/pkg/JupyterKernel-X.Y.Z/bin/jupyter-kernel-gap

And an export command to set `JUPYTER_GAP_EXECUTABLE`:

    export JUPYTER_GAP_EXECUTABLE=gap

### Running JupyterKernel

With all of the setup complete, you should be able to start Jupyter notebook with
  
    jupyter notebook
  
and chose GAP as a kernel option.

### Troubleshooting

If you have registered the GAP Jupyter kernel, but it does not start, open GAP and enter

    LoadPackage("JupyterKernel");

If this returns `fail`, follow the displayed instructions to attempt loading it second
time with a more verbose output in order to find out which of the dependencies fail to
load, and check their installation. If this returns `true` but it still does not work
in Jupyter, check that you have set the environment variable `JUPYTER_GAP_EXECUTABLE`
and the script `jupyter-kernel-gap` is in your path as described above. For some more
details, see <https://github.com/gap-packages/JupyterKernel/issues/74>.

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

