#!/usr/bin/env bash
set -Eeuxo pipefail

[[ "$RUNNER_OS" == 'Windows' ]] && IS_WIN=true || IS_WIN=false
TOP=$(pwd)
BIN=$TOP/bin
EXT=""
PATCHES=$TOP/patches
PROBLEM=$TOP/problems/mult_dist.smt2
$IS_WIN && EXT=".exe"
mkdir -p "$BIN"

deps() {
    case "$RUNNER_OS" in
      Linux) ldd $1 || true ;;
      macOS) otool -L $1 || true ;;
      Windows) ldd $1 || true ;;
    esac
}

build_abc() {
  pushd repos/abc
  if $IS_WIN ; then
    sed -i.bak -e 's/-ldl//' Makefile
    sed -i.bak2 -e 's/-lrt//' Makefile
    echo "double Cudd_CountMinterm( DdManager * manager, DdNode * node, int nvars ) { return 0.0; }" >> src/base/abci/abc.c
    make ABC_USE_NO_READLINE=1 ABC_USE_NO_PTHREADS=1 ABC_USE_NO_CUDD=1 CXXFLAGS="-fpermissive -DNT64 -DWIN32_NO_DLL" CFLAGS="-DNT64 -DWIN32_NO_DLL" LDFLAGS="-static" -j4 abc
  else
    make -j4 abc
  fi
  cp abc$EXT $BIN
  (cd $BIN && deps abc$EXT && ./abc$EXT -S "%blast; &sweep -C 5000; &syn4; &cec -m -s" < $PROBLEM)
  popd
  cleanup_bins
}

build_boolector() {
  pushd repos/boolector
  if $IS_WIN ; then
    export CMAKE_OPTS="-DIS_WINDOWS_BUILD=1"
    # Backport https://github.com/Boolector/boolector/pull/181
    patch -p1 -i $PATCHES/boolector-mingw64.patch
  fi
  ./contrib/setup-lingeling.sh
  ./contrib/setup-btor2tools.sh
  ./configure.sh --ninja
  cd build
  ninja -j4
  cp bin/boolector$EXT $BIN
  (cd $BIN && ./boolector$EXT --version && deps boolector$EXT && ./boolector$EXT $PROBLEM --no-exit-codes)
  popd
  cleanup_bins
}

build_cvc4() {
  pushd repos/CVC4-archived
  if $IS_WIN ; then
    echo "Downloading pre-built CVC4 binary for Windows"
    curl -o cvc4$EXT -sL "https://github.com/CVC4/CVC4/releases/download/1.8/cvc4-1.8-win64-opt.exe"
    cp cvc4$EXT $BIN
    deps cvc4$EXT
  else
    ./contrib/get-antlr-3.4
    ./configure.sh --static --no-static-binary production
    cd build
    make -j4
    cp bin/cvc4$EXT $BIN
    (cd $BIN && ./cvc4$EXT --version && deps cvc4$EXT && ./cvc4$EXT $PROBLEM)
  fi
  popd
  cleanup_bins
}

build_yices() {
  if $IS_WIN ; then
    export CC=x86_64-w64-mingw32-gcc
    export CXX=x86_64-w64-mingw32-g++
  fi
  export CFLAGS="-I$TOP/install-root/include -I$TOP/repos/libpoly/src -I$TOP/repos/libpoly/include"
  export CXXFLAGS="-I$TOP/install-root/include -I$TOP/repos/libpoly/src -I$TOP/repos/libpoly/include"
  export LDFLAGS="-L$TOP/install-root/lib"
  if $IS_WIN ; then
    export CONFIGURE_FLAGS="--build=x86_64-w64-mingw32 --prefix=$TOP/install-root"
  else
    export CONFIGURE_FLAGS="--prefix=$TOP/install-root"
  fi

  mkdir install-root
  mkdir install-root/include
  mkdir install-root/lib

  (cd repos && curl -o gmp.tar.lz -sL "https://gmplib.org/download/gmp/gmp-6.2.1.tar.lz" && tar xf gmp.tar.lz)

  pushd repos/gmp-6.2.1
  ./configure $CONFIGURE_FLAGS
  make -j4
  make install
  popd

  pushd repos/cudd
  case "$RUNNER_OS" in
    Linux) autoreconf ;;
    macOS) autoreconf ;;
    Windows) autoconf ;;
  esac
  ./configure CFLAGS=-fPIC $CONFIGURE_FLAGS
  make -j4
  make install
  popd

  pushd repos/libpoly
  cd build
  if $IS_WIN; then
    cmake .. -DCMAKE_TOOLCHAIN_FILE=$TOP/scripts/libpoly-x86_64-w64-mingw32.cmake -DCMAKE_INSTALL_PREFIX=$TOP/install-root -DGMP_INCLUDE_DIR=$TOP/install-root/include -DGMP_LIBRARY=$TOP/install-root/lib/libgmp.a -DLIBPOLY_BUILD_PYTHON_API=Off -GNinja
  else
    cmake .. -DCMAKE_BUILD_TYPE=Release -DLIBPOLY_BUILD_PYTHON_API=Off -DCMAKE_INSTALL_PREFIX=$TOP/install-root -GNinja
  fi
  ninja -j4 static_poly
  cp ./src/libpoly.a $TOP/install-root/lib
  mkdir -p $TOP/install-root/include/poly
  cp -r ../include/*.h $TOP/install-root/include/poly
  popd

  pushd repos/yices2
  autoconf
  if $IS_WIN; then
    ./configure --enable-mcsat $CONFIGURE_FLAGS
    dos2unix src/frontend/smt2/smt2_tokens.txt
    dos2unix src/frontend/smt2/smt2_keywords.txt
    dos2unix src/frontend/smt2/smt2_symbols.txt
    dos2unix src/frontend/smt1/smt_keywords.txt
    dos2unix src/frontend/yices/yices_keywords.txt
    cp configs/make.include.x86_64-w64-mingw32 configs/make.include.x86_64-pc-mingw64
  else
    ./configure --enable-mcsat $CONFIGURE_FLAGS
  fi
  make -j4 static-bin
  cp build/*/static_bin/* $BIN
  if [ -e $BIN/yices_smt2$EXT ] ; then cp $BIN/yices_smt2$EXT $BIN/yices-smt2$EXT ; else true ; fi
  (cd $BIN && ./yices-smt2$EXT --version && deps yices-smt2$EXT && ./yices-smt2$EXT $PROBLEM)
  popd
  cleanup_bins
}

build_z3() {
  pushd repos/z3
  if $IS_WIN ; then
    sed -i.bak -e 's/STATIC_BIN=False/STATIC_BIN=True/' scripts/mk_util.py
  fi
  python scripts/mk_make.py
  (cd build && make -j4 && cp z3$EXT $BIN)
  popd
  (cd $BIN && ./z3$EXT --version && deps z3$EXT && ./z3$EXT $PROBLEM)
  cleanup_bins
}

cleanup_bins() {
  $IS_WIN || chmod +x $BIN/*
  strip $BIN/*
}

COMMAND="$1"
shift

"$COMMAND" "$@"
