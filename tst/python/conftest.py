"""Pytest setup for the GAP Jupyter kernel test suite.

Verifies the gap-4 kernelspec is installed before tests run; if not, prints
a clear hint instead of failing inscrutably inside jupyter_kernel_test.
"""

import sys

import pytest
from jupyter_client.kernelspec import KernelSpecManager, NoSuchKernel


KERNEL_NAME = "gap-4"


def pytest_configure(config):
    try:
        KernelSpecManager().get_kernel_spec(KERNEL_NAME)
    except NoSuchKernel:
        pytest.exit(
            f"kernel {KERNEL_NAME!r} is not registered with Jupyter.\n"
            f"From the package directory, run:\n"
            f"    pip install -e .\n"
            f"    jupyter kernelspec install --user etc/jupyter --name gap-4\n",
            returncode=2,
        )
