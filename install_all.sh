#!/bin/bash -e
#
#  Copyright (c) 2014, Facebook, Inc.
#  All rights reserved.
#
#  This source code is licensed under the BSD-style license found in the
#  LICENSE file in the root directory of this source tree. An additional grant
#  of patent rights can be found in the PATENTS file in the same directory.
#

echo
echo This script will install fblualib and all its dependencies.
echo It has been tested on Ubuntu 13.10 and Ubuntu 14.04, Linux x86_64.
echo
echo Optionally uses env vars:
echo   NO_ELEVATED_INSTALL=1         runs make install, without sudo
echo   PREFIX=/my/install/dir        passed to ./configure as --prefix
echo   INPLACE=1                     download/build in-place
echo   PY_PREFIX=/my/virtualenv/dir  where to install python modules
echo
echo Note that you must activate your torch environment before calling
echo this script, eg by calling ~/torch/install/bin/torch-activate
echo

set -e
set -x

if [[ $(arch) != 'x86_64' ]]; then
    echo "x86_64 required" >&2
    exit 1
fi

issue=$(cat /etc/issue)
extra_packages=
if [[ $issue =~ ^Ubuntu\ 13\.10 ]]; then
    :
elif [[ $issue =~ ^Ubuntu\ 14 ]]; then
    extra_packages=libiberty-dev
elif [[ $issue =~ ^Ubuntu\ 15\.04 ]]; then
    extra_packages=libiberty-dev
else
    echo "Ubuntu 13.10, 14.* or 15.04 required" >&2
    exit 1
fi

if [[ -v INPLACE ]]; then {
  dir=${PWD}
} else {
  dir=$(mktemp --tmpdir -d fblualib-build.XXXXXX)
} fi

echo Working in $dir
echo
cd $dir

INSTALL_CMD="sudo make install"
if [[ -v NO_ELEVATED_INSTALL ]]; then {
  INSTALL_CMD="make install"
} fi

if [[ -v PREFIX ]]; then {
  export CPATH=${CPATH}:${PREFIX}/include
  export LIBRARY_PATH=$LIBRARY_PATH:${PREFIX}/lib
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${PREFIX}/lib
  _PREFIX=${PREFIX}
} else {
  _PREFIX=/usr/local
} fi

if [[ -v PY_PREFIX ]]; then {
  export PY_PREFIX
} fi

echo Installing required packages
echo
sudo apt-get install -y \
    git \
    curl \
    wget \
    g++ \
    automake \
    autoconf \
    autoconf-archive \
    libtool \
    libboost-all-dev \
    libevent-dev \
    libdouble-conversion-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    liblz4-dev \
    liblzma-dev \
    libsnappy-dev \
    make \
    zlib1g-dev \
    binutils-dev \
    libjemalloc-dev \
    $extra_packages \
    flex \
    bison \
    libkrb5-dev \
    libsasl2-dev \
    libnuma-dev \
    pkg-config \
    libssl-dev \
    libedit-dev \
    libmatio-dev \
    libpython-dev \
    libpython3-dev \
    python-numpy

echo
echo Cloning repositories
echo
if [[ ! -d folly ]]; then git clone -b v0.35.0  --depth 1 https://github.com/facebook/folly.git; fi
if [[ ! -d fbthrift ]]; then git clone -b v0.24.0  --depth 1 https://github.com/facebook/fbthrift.git; fi
if [[ ! -d thpp ]]; then git clone https://github.com/facebook/thpp; fi
if [[ ! -v INPLACE ]]; then {
  git clone https://github.com/facebook/fblualib
} fi

echo
echo Building folly
echo

cd $dir/folly/folly
if [[ ! -f Makefile ]] ; then {
  autoreconf -ivf
  ./configure --prefix=${_PREFIX}
} fi
make -j $(getconf _NPROCESSORS_ONLN)
${INSTALL_CMD}
sudo ldconfig # reload the lib paths after freshly installed folly. fbthrift needs it.

echo
echo Building fbthrift
echo

cd $dir/fbthrift/thrift
if [[ ! -f Makefile ]] ; then {
  autoreconf -ivf
  ./configure --prefix=${_PREFIX}
} fi
(
  cd compiler/py
  sed -i -e '/mkdir -p $(PY_INSTALL_HOME/d' Makefile
)
make -j $(getconf _NPROCESSORS_ONLN)
${INSTALL_CMD}

echo
echo 'Installing TH++'
echo

cd $dir/thpp/thpp
if [[ ! -v PREFIX ]]; then {
  ./build.sh
} else {
  mkdir -p build
  cd build
  cmake .. \
    -DCMAKE_INSTALL_PREFIX=${_PREFIX} \
    -DFOLLY_INCLUDE_DIR=${_PREFIX}/include -DFOLLY_LIBRARY=${_PREFIX}/lib/libfolly.so \
    -DTHRIFT_INCLUDE_DIR=${_PREFIX}/include -DTHRIFT_LIBRARY=${_PREFIX}/lib/libthrift.so -DTHRIFT_CPP2_LIBRARY=${_PREFIX}/lib/libthriftcpp2.so
  make -j $(getconf _NPROCESSORS_ONLN)
  ${INSTALL_CMD}
} fi

echo
echo 'Installing FBLuaLib'
echo

if [[ ! -v PREFIX ]]; then {
  cd $dir/fblualib/fblualib
  ./build.sh
} else {
  cd $dir/fblualib
  mkdir -p build
  cd build
  cmake .. \
    -DCMAKE_INSTALL_PREFIX=${_PREFIX} \
    -DFOLLY_INCLUDE_DIR=${_PREFIX}/include -DFOLLY_LIBRARY=${_PREFIX}/lib/libfolly.so \
    -DTHRIFT_INCLUDE_DIR=${_PREFIX}/include -DTHRIFT_LIBRARY=${_PREFIX}/lib/libthrift.so -DTHRIFT_CPP2_LIBRARY=${_PREFIX}/lib/libthriftcpp2.so
  make -j $(getconf _NPROCESSORS_ONLN)
  ${INSTALL_CMD}
} fi

echo
echo 'All done!'
echo

