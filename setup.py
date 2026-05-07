#!/usr/bin/env python

import setuptools, sys
from setuptools.command.bdist_egg import bdist_egg


class bdist_egg_disabled(bdist_egg):
    """Disabled version of bdist_egg.

    Prevents `setup.py install` from performing setuptools' default
    easy_install. Use `pip install .` instead.
    """

    def run(self):
        sys.exit("Aborting implicit building of eggs. Use `pip install .` to install from source.")


setuptools.setup(
    name="gap-jupyter",
    include_package_data=True,
    cmdclass={
        "bdist_egg": bdist_egg_disabled,
    },
    packages=["gap_jupyter_kernel"],
    data_files=[
        # install kernel spec
        ("share/jupyter/kernels/gap-4", [
            "etc/jupyter/kernel.json",
            "etc/jupyter/logo-32x32.png",
            "etc/jupyter/logo-64x64.png",
        ]),
    ],
    zip_safe=False,
    install_requires=["jupyter_client>=8.0"],
    extras_require={
        "test": ["jupyter_kernel_test>=0.7", "pytest>=7"],
    },
    python_requires=">=3.8",
)
