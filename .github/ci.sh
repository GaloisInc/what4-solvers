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
  if $IS_WIN; then
    7z x -bd abc.zip;
    pushd abc-$ABC_VERSION
    sed -i 's#ABC_USE_PTHREADS"#ABC_DONT_USE_PTHREADS" /D "_XKEYCHECK_H"#g' *.dsp
    awk 'BEGIN { del=0; } /# Begin Group "uap"/ { del=1; } /# End Group/ { if( del > 0 ) {del=0; next;} } del==0 {print;} ' abclib.dsp > tmp.dsp
    cp tmp.dsp abclib.dsp
    rm tmp.dsp
    unix2dos *.dsp
    devenv abcspace.dsw /upgrade || dir
    msbuild abcspace.sln /m /nologo /p:Configuration=Release
    cp _TEST/abc$EXT $BIN/abc$EXT
    popd
  else
    unzip abc.zip;
    (cd abc-$ABC_VERSION && make && cp abc$EXT $BIN/abc$EXT)
  fi
  output path $BIN/abc$EXT
}

build_cvc4() {
  curl -o cvc4.zip -sL "https://github.com/CVC4/CVC4-archived/archive/refs/tags/$CVC4_VERSION.zip"
  if $IS_WIN; then 7z x -bd cvc4.zip; else unzip cvc4.zip; fi
  (cd CVC4-archived-$CVC4_VERSION && ./contrib/get-antlr-3.4 && ./configure.sh production && cd build && make)
}

build_yices() {
  curl -o yices.zip -sL "https://github.com/SRI-CSL/yices2/archive/refs/tags/Yices-$YICES_VERSION.zip"
  if $IS_WIN; then 7z x -bd yices.zip; else unzip yices.zip; fi
  (cd yices2-Yices-$YICES_VERSION && autoconf && ./configure && make && cp build/*/bin/* $BIN)
  output path $BIN/yices$EXT
  output path $BIN/yices_smt2$EXT
}

build_z3() {
  curl -o z3.zip -sL "https://github.com/Z3Prover/z3/archive/refs/tags/z3-$Z3_VERSION.zip"
  if $IS_WIN; then 7z x -bd z3.zip; else unzip z3.zip; fi
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
