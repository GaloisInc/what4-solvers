#!/usr/bin/env bash
set -Eeuxo pipefail

[[ "$RUNNER_OS" == 'Windows' ]] && IS_WIN=true || IS_WIN=false
TOP=$(pwd)
BIN=$TOP/bin
EXT=""
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
    make ABC_USE_NO_READLINE=1 ABC_USE_NO_PTHREADS=1 ABC_USE_NO_CUDD=1 CXXFLAGS="-fpermissive -DNT64" CFLAGS="-DNT64" -j4 abc
  else
    make -j4 abc
  fi
  cp abc$EXT $BIN
  (cd $BIN && deps abc$EXT && ./abc$EXT -S "%blast; &sweep -C 5000; &syn4; &cec -m -s" < $PROBLEM)
  popd
}

build_cvc4() {
  pushd repos/CVC4-archived
  if $IS_WIN ; then
    echo "Downloading pre-built CVC4 binary for Windows"
    curl -o cvc4$EXT -sL "https://github.com/CVC4/CVC4/releases/download/1.8/cvc4-1.8-win64-opt.exe"
    cp cvc4$EXT $BIN
  else
    ./contrib/get-antlr-3.4
    ./configure.sh --static --no-static-binary production
    cd build
    make -j4
    cp bin/cvc4$EXT $BIN
    (cd $BIN && ./cvc4$EXT --version && deps cvc4$EXT && ./cvc4$EXT $PROBLEM)
  fi
  popd
}

build_yices() {
  if false ; then # "$IS_WIN"; then
    echo "Downloading pre-built Yices binary for Windows"
    curl -o yices.zip -sL "https://yices.csl.sri.com/releases/2.6.2/yices-2.6.2-x86_64-pc-mingw32-static-gmp.zip"
    unzip yices.zip
    cp yices-*/bin/* $BIN
  else
    export CFLAGS="-I$TOP/install-root/include -I$TOP/repos/libpoly/src -I$TOP/repos/libpoly/include"
    export CXXFLAGS="-I$TOP/install-root/include -I$TOP/repos/libpoly/src -I$TOP/repos/libpoly/include"
    export LDFLAGS="-L$TOP/install-root/lib"

    mkdir install-root
    mkdir install-root/include
    mkdir install-root/lib

    # This is failing on Windows due to failing to find 'utils/open_memstream.h'
    pushd repos/libpoly
    cd build
    if $IS_WIN; then
      sed -i.bak -e 's/enable_testing()//' ../CMakeLists.txt
      sed -i.bak -e 's/add_subdirectory(test\/polyxx)//' ../CMakeLists.txt
      cmake .. -DCMAKE_BUILD_TYPE=Release -DLIBPOLY_BUILD_PYTHON_API=Off -DCMAKE_INSTALL_PREFIX=$TOP/install-root -DHAVE_OPEN_MEMSTREAM=0
    else
      cmake .. -DCMAKE_BUILD_TYPE=Release -DLIBPOLY_BUILD_PYTHON_API=Off -DCMAKE_INSTALL_PREFIX=$TOP/install-root
    fi
    make -j4
    make install
    popd

    pushd repos/cudd
    case "$RUNNER_OS" in
      Linux) autoreconf ;;
      macOS) autoconf ;;
      Windows) autoconf ;;
    esac
    ./configure CFLAGS=-fPIC --prefix=$TOP/install-root
    make -j4
    make install
    popd

    pushd repos/yices2
    autoconf
    if $IS_WIN; then # Currently unreachable, but leaving in for when it's relevant again
      ./configure
      dos2unix src/frontend/smt2/smt2_tokens.txt
      dos2unix src/frontend/smt2/smt2_keywords.txt
      dos2unix src/frontend/smt2/smt2_symbols.txt
      dos2unix src/frontend/smt1/smt_keywords.txt
      dos2unix src/frontend/yices/yices_keywords.txt
      make -j4 OPTION=mingw64 static-bin
    else
      ./configure --enable-mcsat
      make -j4 static-bin
    fi
    cp build/*/static_bin/* $BIN
    if [ -e $BIN/yices_smt2$EXT ] ; then cp $BIN/yices_smt2$EXT $BIN/yices-smt2$EXT ; else true ; fi
    (cd $BIN && ./yices-smt2$EXT --version && deps yices-smt2$EXT && ./yices-smt2$EXT $PROBLEM)
    popd
  fi
}

build_z3() {
  (cd repos/z3 && python scripts/mk_make.py && cd build && make -j4 && cp z3$EXT $BIN)
  (cd $BIN && ./z3$EXT --version && deps z3$EXT && ./z3$EXT $PROBLEM)
}

build_solvers() {
  #build_abc
  build_yices
  #build_cvc4
  #build_z3
  $IS_WIN || chmod +x $BIN/*
  strip $BIN/*
}

COMMAND="$1"
shift

"$COMMAND" "$@"
