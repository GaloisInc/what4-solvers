#!/usr/bin/env bash
set -Eeuxo pipefail

[[ "$RUNNER_OS" == 'Windows' ]] && IS_WIN=true || IS_WIN=false
[[ "$RUNNER_OS" == 'Linux' ]] && IS_LINUX=true || IS_LINUX=false
TOP=$(pwd)
BIN=$TOP/bin
EXT=""
PATCHES=$TOP/patches
PROBLEM=$TOP/problems/mult_dist.smt2
$IS_WIN && EXT=".exe"

# Detect Linux distribution
IS_UBUNTU=false
IS_REDHAT=false
if $IS_LINUX; then
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      ubuntu)
        IS_UBUNTU=true
        ;;
      rhel)
        IS_REDHAT=true
        ;;
      *)
        ;;
    esac
  fi
fi

mkdir -p "$BIN"

deps() {
    case "$RUNNER_OS" in
      Linux) ldd $1 || true ;;
      macOS) otool -L $1 || true ;;
      Windows) ldd $1 || true ;;
    esac
}

# Build static GMP library from source
# Used by bitwuzla and yices when static GMP is not available
ensure_static_gmp() {
  if [ ! -f "$TOP/install-root/lib/libgmp.a" ]; then
    echo "Building static GMP from source..."
    mkdir -p install-root/include
    mkdir -p install-root/lib

    GMP_VERSION="6.3.0"

    # Download and extract GMP if not already present
    if [ ! -d "repos/gmp-$GMP_VERSION" ]; then
      (cd repos && curl -o gmp.tar.lz -sL "https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VERSION.tar.lz" && tar xf gmp.tar.lz)
    fi

    pushd "repos/gmp-$GMP_VERSION"

    # Make gmp-6.3.0 build with GCC >=15
    patch -p1 -i $PATCHES/gmp-gcc-15-fix.patch

    # On intel MacOS 15.x, gmp-6.3.0 started building broken libs full
    # of text relocations. Force --with-pic to stop this. Otherwise, gmp
    # succeeds, but the resulting library doesn't work.
    # To make the set of configure flags slightly more consistent, we always use
    # --with-pic on macOS, both on x86-64 and AArch64.
    case "$RUNNER_OS" in
      macOS) GMP_CONFIGURE_FLAGS=--with-pic;;
      *) GMP_CONFIGURE_FLAGS=;;
    esac

    ./configure --prefix=$TOP/install-root --enable-static --disable-shared --enable-cxx $GMP_CONFIGURE_FLAGS
    make -j4
    make install
    popd
  fi
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
    # Check if readline is available
    # On RedHat/UBI9 and some other distributions, readline-devel is not available
    # so we build without readline support for better compatibility
    if $IS_REDHAT || [ ! -f /usr/include/readline/readline.h ]; then
      echo "Building ABC without readline (not available or RedHat-based system)"
      make OPTFLAGS="-O2" ABC_USE_NO_READLINE=1 -j4 abc
    else
      echo "Building ABC with readline support"
      make OPTFLAGS="-O2" -j4 abc
    fi
  fi
  cp abc$EXT $BIN
  popd
  cleanup_bins
}

build_bitwuzla() {
  # Always build static GMP for bitwuzla
  # Bitwuzla requires gmpxx.h (C++ bindings) which are not always available
  # in system GMP packages (e.g., macOS Homebrew GMP, RedHat UBI9)
  ensure_static_gmp

  # Set environment variables to use our static GMP
  export PKG_CONFIG_PATH="$TOP/install-root/lib/pkgconfig"
  export CFLAGS="-I$TOP/install-root/include"
  export LDFLAGS="-L$TOP/install-root/lib"

  pushd repos/bitwuzla
  # Backport the changes from
  # https://github.com/bitwuzla/bitwuzla/commit/d30ef4147eb2cbe21267702a1c0be60e01d353cd
  # to make Bitwuzla build with GCC >=15
  patch -p1 -i $PATCHES/bitwuzla-gcc-15-fix.patch
  ./configure.py
  cd build
  ninja -j4
  cp src/main/bitwuzla$EXT $BIN
  popd
  cleanup_bins
}

build_cvc4() {
  pushd repos/CVC4-archived
  # Make the get-antlr script work on both x86-64 and AArch64
  patch -p1 -i $PATCHES/cvc4-antlr-check-aarch64.patch
  # Fix a pointer-to-integer cast in ANTLR
  patch -p1 -i $PATCHES/cvc4-antlr-pointer-to-integer-cast.patch
  # Add missing #include statements that Clang++ requires in macos-14 or later.
  patch -p1 -i $PATCHES/cvc4-fix-missing-includes.patch
  # Backport a fix for https://github.com/cvc5/cvc5/issues/10591, which causes
  # bash-5.2 to spuriously replace uses of ampersands (&) in text replacement.
  # This patch was accumulated from the following CVC5 pull requests:
  #
  # * https://github.com/cvc5/cvc5/pull/9233
  # * https://github.com/cvc5/cvc5/pull/9330
  # * https://github.com/cvc5/cvc5/pull/9338
  patch -p1 -i $PATCHES/cvc4-fix-spurious-bash-replacements.patch
  ./contrib/get-antlr-3.4
  ./contrib/get-symfpu
  if $IS_WIN ; then
    # Backport changes from https://github.com/cvc5/cvc5/pull/7512 needed to
    # build CVC4 natively on Windows.
    patch -p1 -i $PATCHES/cvc4-win64-native.patch
    # GitHub Actions comes preinstalled with Chocolatey's mingw package, which
    # includes the ld.gold linker. This does not play nicely with MSYS2's
    # mingw-w64-x86_64-gcc, so we must prevent CMake from using ld.gold.
    # (Ideally, there would be a CMake configuration option to accomplish this,
    # but I have not found one.)
    patch -p1 -i $PATCHES/cvc4-no-ld-gold.patch
    ./configure.sh --static --static-binary --symfpu --win64-native production
  else
    ./configure.sh --static --no-static-binary --symfpu production
  fi
  cd build
  make -j4
  cp bin/cvc4$EXT $BIN
  popd
  cleanup_bins
}

build_cvc5() {
  pushd repos/cvc5

  # Detect Python executable
  # In GitHub Actions, use pythonLocation if available
  # Otherwise, find python3 or python in PATH
  if [ -n "${pythonLocation:-}" ]; then
  PYTHON_EXE="${pythonLocation}/python${EXT}"
  else
  PYTHON_EXE=$(which python3 2>/dev/null || which python 2>/dev/null)
  fi
  echo "Using Python: $PYTHON_EXE"

  if $IS_WIN ; then
    # Why do we manually override Python_EXECUTABLE below? GitHub Actions comes
    # with multiple versions of Python pre-installed, and for some bizarre
    # reason, CMake always tries to pick the latest version, even if it is not
    # on the PATH. Manually overriding this option avoids this oddity.
    ./configure.sh -DPython_EXECUTABLE=$PYTHON_EXE --static --static-binary --auto-download --win64-native production
  else
    ./configure.sh -DPython_EXECUTABLE=$PYTHON_EXE --static --no-static-binary --auto-download production
  fi
  cd build
  make -j4
  cp bin/cvc5$EXT $BIN
  popd
  cleanup_bins
}

build_yices() {
  if $IS_WIN ; then
    export CC=x86_64-w64-mingw32-gcc
    export CXX=x86_64-w64-mingw32-g++
  fi
  if $IS_WIN ; then
    export CONFIGURE_FLAGS="--build=x86_64-w64-mingw32 --prefix=$TOP/install-root"
  else
    export CONFIGURE_FLAGS="--prefix=$TOP/install-root"
  fi

  mkdir -p install-root/include
  mkdir -p install-root/lib

  # Build static GMP using shared function
  ensure_static_gmp

  # Set up environment for yices build
  export CFLAGS="-I$TOP/install-root/include -I$TOP/repos/libpoly/src -I$TOP/repos/libpoly/include"
  export CXXFLAGS="-I$TOP/install-root/include -I$TOP/repos/libpoly/src -I$TOP/repos/libpoly/include"
  export LDFLAGS="-L$TOP/install-root/lib"

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
  popd
  cleanup_bins
}

build_z3-4.8.8() {
  build_z3 "4.8.8"
}

build_z3-4.8.14() {
  build_z3 "4.8.14"
}

build_z3() {
  Z3_BIN="z3-$1"
  pushd repos/$Z3_BIN
  patch -p1 -i $PATCHES/$Z3_BIN-gcc-15-fix.patch
  mkdir build
  cd build
  if $IS_WIN ; then
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS:STRING='-static' -GNinja
  else
    cmake .. -DCMAKE_BUILD_TYPE=Release -GNinja
  fi
  ninja -j4
  cp z3$EXT $BIN/$Z3_BIN$EXT
  popd
  cleanup_bins
}

cleanup_bins() {
  $IS_WIN || chmod +x $BIN/*
  strip $BIN/*
}

# Test a solver by running it on the test problem
# Usage: test_solver <solver_name>
test_solver() {
  SOLVER="$1"
  echo "Testing $SOLVER with $PROBLEM..."

  cd "$BIN"

  # Run the solver and capture output
  case "$SOLVER" in
    abc)
      RESULT=$(deps abc$EXT && ./abc$EXT -S "%blast; &sweep -C 5000; &syn4; &cec -m -s" < "$PROBLEM")
      ;;
    yices)
      RESULT=$(./yices-smt2$EXT --version && deps yices-smt2$EXT && ./yices-smt2$EXT "$PROBLEM")
      ;;
    *)
      # Most solvers use the same invocation pattern
      RESULT=$(./$SOLVER$EXT --version && deps $SOLVER$EXT && ./$SOLVER$EXT "$PROBLEM")
      ;;
  esac

  # Check if the result contains "unsat"
  if echo "$RESULT" | grep -q "unsat"; then
    echo "✓ Test passed for $SOLVER (returned unsat)"
  else
    echo "✗ Test failed for $SOLVER: expected 'unsat', got:"
    echo "$RESULT"
    return 1
  fi
}

# GitHub Actions' runners have somewhat unusual naming conventions. For
# instance, there are both ubuntu-24.04 and ubuntu-24.04-arm runners. Each of
# them has a distinct architecture (the former is x86-64, and the latter is
# ARM64), but only ubuntu-24.04-arm explicitly encodes its architecture in the
# runner name. Similarly, there is a macos-15-intel runner that encodes the
# architecture (Intel x86-64) in the runner name.
#
# For the sake of producing what4-solvers binary distributions, we would like to
# normalize runner names by stripping architecture suffixes. (We attach the
# architecture to the bindist name separately.)
normalize_runner_name() {
  ORIG_NAME="$1"
  # Strip -arm suffix (for Ubuntu ARM runners)
  NORMALIZED_NAME=${ORIG_NAME%"-arm"}
  # Strip -intel suffix (for macOS Intel runners)
  NORMALIZED_NAME=${NORMALIZED_NAME%"-intel"}
  echo "$NORMALIZED_NAME"
}

COMMAND="$1"
shift

"$COMMAND" "$@"
