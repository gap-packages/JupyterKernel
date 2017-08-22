#!/usr/bin/env bash
set -ex

# build GAP in a subdirectory
git clone --depth=2 https://github.com/gap-system/gap.git $GAPROOT
cd $GAPROOT
./autogen.sh
./configure
make -j4 V=1
make bootstrap-pkg-minimal

if [[ $ABI == 32 ]]
then
    CONFIGFLAGS="CFLAGS=-m32 LDFLAGS=-m32 LOPTS=-m32 CXXFLAGS=-m32"
fi

# build some packages...
cd pkg

# install latest version of io
git clone https://github.com/gap-packages/io
cd io
./autogen.sh
./configure $CONFIGFLAGS
make -j4 V=1
cd ..

# install latest version of profiling
git clone https://github.com/gap-packages/profiling
cd profiling
./autogen.sh
# HACK to workaround problems when building with clang
if [[ $CC = clang ]]
then
    export CXX=clang++
fi
./configure $CONFIGFLAGS
make -j4 V=1
cd ..

# install latest version of uuid
git clone https://github.com/gap-packages/uuid

# install latest version of crypting
git clone https://github.com/gap-packages/crypting
cd crypting
./autogen.sh
./configure $CONFIGFLAGS
make -j4 V=1
cd ..

# install latest version of ZeroMQInterface
git clone https://github.com/gap-packages/ZeroMQInterface
cd ZeroMQInterface
./autogen.sh
./configure $CONFIGFLAGS
make -j4 V=1
cd ..

# install latest version of json
git clone https://github.com/gap-packages/json
cd json
./autogen.sh
./configure $CONFIGFLAGS
make -j4 V=1
cd ..
