"""Launcher for the GAP Jupyter kernel.

This module is invoked by Jupyter via the entry in ``etc/jupyter/kernel.json``
(``python -m gap_jupyter_kernel {connection_file}``). It locates the GAP
executable and execs it with the kernel bootstrap script.
"""
