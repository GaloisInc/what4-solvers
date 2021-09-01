#!/usr/bin/env bash
set -Eeuxo pipefail

[[ "$RUNNER_OS" == 'Windows' ]] && IS_WIN=true || IS_WIN=false
BIN=$(pwd)/bin
EXT=""
$IS_WIN && EXT=".exe"
mkdir -p "$BIN"

is_exe() { [[ -x "$1/$2$EXT" ]] || command -v "$2" > /dev/null 2>&1; }

build_abc() {
  curl -o "abc.zip" -sL "https://github.com/berkeley-abc/abc/archive/$ABC_VERSION.zip"
  unzip abc.zip
  (cd abc-$ABC_VERSION && make ABC_USE_NO_READLINE=1 && cp abc$EXT $BIN/abc$EXT)
  output path $BIN/abc$EXT
}

build_cvc4() {
  curl -o cvc4.zip -sL "https://github.com/CVC4/CVC4-archived/archive/refs/tags/$CVC4_VERSION.zip"
  unzip cvc4.zip
  (cd CVC4-archived-$CVC4_VERSION && ./contrib/get-antlr-3.4 && ./configure.sh production && cd build && make)
}

build_yices() {
  curl -o yices.zip -sL "https://github.com/SRI-CSL/yices2/archive/refs/tags/Yices-$YICES_VERSION.zip"
  unzip yices.zip
  (cd yices2-Yices-$YICES_VERSION && autoconf && ./configure && make && cp build/*/bin/* $BIN)
  output path $BIN/yices$EXT
  output path $BIN/yices_smt2$EXT
}

build_z3() {
  curl -o z3.zip -sL "https://github.com/Z3Prover/z3/archive/refs/tags/z3-$Z3_VERSION.zip"
  unzip z3.zip
  (cd z3-z3-$Z3_VERSION && python scripts/mk_make.py && cd build && make && cp z3$EXT $BIN/z3$EXT)
  output path $BIN/z3$EXT
}

build_solvers() {
  build_abc
  build_cvc4
  build_yices
  build_z3
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
