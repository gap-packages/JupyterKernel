#!/usr/bin/env python

# Extremely simplistic (read: probably wrong) script to register the native
# GAP Jupyter Kernel with the Jupyter installation

import os
import sys
import json
import argparse

from notebook.nbextensions import check_nbextension, install_nbextension, enable_nbextension
from jupyter_client.kernelspec import install_kernel_spec


# Installs the Kernel Spec and NBExtension for Syntax Highlighting
# I am not sure whether this is the correct way of doing it, but
# it works right now
# TODO: Find out whether there is a cleaner way
def install(args):
    # Write kernel spec in a temporary directory
    user = False
    if "user" in args: 
        user = args.user

    print("Installing jupyter kernel spec")
    install_kernel_spec('etc/jupyter/', kernel_name='gap-4', user=user)

    print("Installing nbextension for syntax hilighting")
    install_nbextension('etc/gap-mode',
                        overwrite=True, user=user)
    enable_nbextension('notebook', 'gap-mode/main',)


parser = argparse.ArgumentParser(description='Register JupyterKernel with Jupyter installation.')
subparsers = parser.add_subparsers(help='install help')

parser_install = subparsers.add_parser('install', help='install help')
parser_install.add_argument('--user', dest='user', action='store_const', const=True, default=False
                                    , help='Install into user\'s Jupyter installation') 
parser.set_defaults(func=install)

args = parser.parse_args()
args.func(args)
