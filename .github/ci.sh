#!/usr/bin/env bash
set -Eeuxo pipefail

[[ "$RUNNER_OS" == 'Windows' ]] && IS_WIN=true || IS_WIN=false
BIN=$(pwd)/bin
EXT=""
$IS_WIN && EXT=".exe"
mkdir -p "$BIN"

is_exe() { [[ -x "$1/$2$EXT" ]] || command -v "$2" > /dev/null 2>&1; }

build_abc() {
  (cd repos/abc && git checkout $ABC_TAG && make ABC_USE_NO_READLINE=1 && cp abc$EXT $BIN/abc$EXT)
  output path $BIN/abc$EXT
}

build_cvc4() {
  pushd repos/CVC4-archived
  git checkout $CVC4_TAG
  if $IS_WIN ; then
    echo "Downloading pre-built CVC4 binary for Windows"
    file="win64-opt.exe"
    curl -o cvc4$EXT -sL "https://github.com/CVC4/CVC4/releases/download/$version/cvc4-$CVC4_TAG-$file"
  else
    ./contrib/get-antlr-3.4
    ./configure.sh production
    cd build
    make
    cp bin/cvc4$EXT $BIN
  fi
  popd
  output path $BIN/cvc4$EXT
}

build_yices() {
  if "$IS_WIN"; then
    echo "Skipping libpoly and CUDD on Windows"
  else
    TOP=`pwd`

    export CPPFLAGS="-I$TOP/install-root/include"
    export LDFLAGS="-L$TOP/install-root/lib"

    mkdir install-root
    mkdir install-root/include
    mkdir install-root/lib

    pushd repos/libpoly
    git checkout $LIBPOLY_TAG
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
    git checkout $CUDD_TAG
    ./configure CFLAGS=-fPIC --prefix=$TOP/install-root
    make
    make install
    popd
  fi

  pushd repos/yices2
  git checkout $YICES_TAG
  autoconf
  if $IS_WIN; then
    ./configure --host=x86_64-w64-mingw32 --build=x86_64-w64-mingw32
    cp configs/make.include.x86_64-w64-mingw32 configs/make.include.x86_64-pc-mingw64
  else
    ./configure --enable-mcsat
  fi
  make
  cp build/*/bin/* $BIN
  popd
  output path $BIN/yices$EXT
  output path $BIN/yices_smt2$EXT
}

build_z3() {
  (cd repos/z3 && git checkout $Z3_TAG && python scripts/mk_make.py && cd build && make && cp z3$EXT $BIN/z3$EXT)
  output path $BIN/z3$EXT
}

build_solvers() {
  build_abc
  build_cvc4
  build_yices
  build_z3
  $IS_WIN || chmod +x $BIN/*
  #export PATH="$BIN:$PATH"
  #echo "$BIN" >> "$GITHUB_PATH"
  #is_exe "$BIN" abc && is_exe "$BIN" cvc4 && is_exe "$BIN" yices && is_exe "$BIN" z3
}

output() { echo "::set-output name=$1::$2"; }
set_files() { output changed-files "$(files_since "$1" "$2")"; }
files_since() {
  changed_since="$(git log -1 --before="@{$2}")"
  files="${changed_since:+"$(git diff-tree --no-commit-id --name-only -r "$1" | xargs)"}"
  echo "$files"
}

COMMAND="$1"
shift

"$COMMAND" "$@"
