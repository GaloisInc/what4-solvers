#!/usr/bin/env bash
set -Eeuxo pipefail

[[ "$RUNNER_OS" == 'Windows' ]] && IS_WIN=true || IS_WIN=false
BIN=$(pwd)/bin
EXT=""
$IS_WIN && EXT=".exe"
mkdir -p "$BIN"

build_abc() {
  pushd repos/abc
  if $IS_WIN ; then
    sed -i.bak -e 's/-ldl//' Makefile
    sed -i.bak2 -e 's/-lrt//' Makefile
    make ABC_USE_NO_READLINE=1 ABC_USE_NO_PTHREADS=1 CXXFLAGS=-fpermissive
  else
    make
  fi
  cp abc$EXT $BIN/abc$EXT
  popd
}

build_cvc4() {
  pushd repos/CVC4-archived
  if $IS_WIN ; then
    echo "Downloading pre-built CVC4 binary for Windows"
    curl -o cvc4$EXT -sL "https://github.com/CVC4/CVC4/releases/download/1.8/cvc4-1.8-win64-opt.exe"
  else
    ./contrib/get-antlr-3.4
    ./configure.sh production
    cd build
    make
    cp bin/cvc4$EXT $BIN
  fi
  popd
}

build_yices() {
  if "$IS_WIN"; then
    echo "Downloading pre-built Yices binary for Windows"
    curl -o yices.zip -sL "https://yices.csl.sri.com/releases/2.6.2/yices-2.6.2-x86_64-pc-mingw32-static-gmp.zip"
    unzip yices.zip
    cp yices-*/bin/* $BIN
  else
    TOP=`pwd`

    export CPPFLAGS="-I$TOP/install-root/include"
    export LDFLAGS="-L$TOP/install-root/lib"

    mkdir install-root
    mkdir install-root/include
    mkdir install-root/lib

    pushd repos/libpoly
    cd build
    if $IS_WIN; then
      CPPFLAGS="$CPPFLAGS -I$TOP/repos/libpoly/src" cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=../cmake/x86_64-w64-mingw32.cmake -DLIBPOLY_BUILD_PYTHON_API=Off -DCMAKE_INSTALL_PREFIX=../install-root -DGMP_INCLUDE_DIR=/mingw64/include -DGMP_LIBRARY=/mingw64/lib/libgmp.a -DHAVE_OPEN_MEMSTREAM=0
    else
      cmake .. -DCMAKE_BUILD_TYPE=Release -DLIBPOLY_BUILD_PYTHON_API=Off -DCMAKE_INSTALL_PREFIX=$TOP/install-root
    fi
    make
    make install
    popd

    pushd repos/cudd
    ./configure CFLAGS=-fPIC --prefix=$TOP/install-root
    make
    make install
    popd

    pushd repos/yices2
    autoconf
    if $IS_WIN; then # Currently unreachable, but leaving in for when it's relevant again
      ./configure --host=x86_64-w64-mingw32 --build=x86_64-w64-mingw32
      cp configs/make.include.x86_64-w64-mingw32 configs/make.include.x86_64-pc-mingw64
    else
      ./configure --enable-mcsat
    fi
    make
    cp build/*/bin/* $BIN
    popd
  fi
}

build_z3() {
  (cd repos/z3 && python scripts/mk_make.py && cd build && make && cp z3$EXT $BIN/z3$EXT)
}

build_solvers() {
  #build_abc
  build_cvc4
  build_yices
  build_z3
  $IS_WIN || chmod +x $BIN/*
}

COMMAND="$1"
shift

"$COMMAND" "$@"
