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
    # Windows does not have libdl or librt
    sed -i.bak -e 's/-ldl//' Makefile
    sed -i.bak2 -e 's/-lrt//' Makefile
    # By default, the Windows build of ABC will write an `abc.history` file
    # to the current directory every time it is invoked. For consistency with
    # ABC's behavior on other OSes, we disable this feature.
    sed -i.bak3 -e 's/#define ABC_USE_HISTORY 1//' src/base/cmd/cmdHist.c
    # Work around https://github.com/berkeley-abc/abc/issues/136
    echo "double Cudd_CountMinterm( DdManager * manager, DdNode * node, int nvars ) { return 0.0; }" >> src/base/abci/abc.c
    # Work around https://github.com/berkeley-abc/abc/issues/154
    patch -p1 -i $PATCHES/abc-intptr_t.patch
    make OPTFLAGS="-O2" ABC_USE_NO_READLINE=1 ABC_USE_NO_PTHREADS=1 ABC_USE_NO_CUDD=1 CXXFLAGS="-fpermissive -DNT64 -DWIN32_NO_DLL" CFLAGS="-DNT64 -DWIN32_NO_DLL" LDFLAGS="-static" -j4 abc
  else
    make OPTFLAGS="-O2" -j4 abc
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
  else
    ./contrib/get-antlr-3.4
    ./contrib/get-symfpu
    ./configure.sh --static --no-static-binary --symfpu production
    cd build
    make -j4
    cp bin/cvc4$EXT $BIN
  fi
  (cd $BIN && ./cvc4$EXT --version && deps cvc4$EXT && ./cvc4$EXT $PROBLEM)
  popd
  cleanup_bins
}

build_cvc5() {
  pushd repos/cvc5
  if $IS_WIN ; then
    # TODO: Once https://github.com/cvc5/cvc5/pull/7512 lands, build a native
    # Windows version of CVC5 instead.
    echo "Downloading pre-built CVC5 binary for Windows"
    curl -o cvc5$EXT -sL "https://github.com/cvc5/cvc5/releases/download/cvc5-1.0.2/cvc5-Win64.exe"
    cp cvc5$EXT $BIN
  else
    ./configure.sh --static --no-static-binary --auto-download production
    cd build
    make -j4
    cp bin/cvc5$EXT $BIN
  fi
  (cd $BIN && ./cvc5$EXT --version && deps cvc5$EXT && ./cvc5$EXT $PROBLEM)
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
