#!/usr/bin/env bash
# Test functions for what4-solvers
# This file is sourced by .github/ci.sh and can also be used standalone

set -Eeuo pipefail

# Detect Windows if not already set
if [ -z "${IS_WIN:-}" ]; then
  [[ "${RUNNER_OS:-$(uname)}" == 'Windows' ]] && IS_WIN=true || IS_WIN=false
fi

# Set extension based on OS
EXT=""
$IS_WIN && EXT=".exe"

# Set default paths if not already set
TOP="${TOP:-$(pwd)}"
PROBLEM="${PROBLEM:-$TOP/problems/mult_dist.smt2}"

# deps function for showing library dependencies
deps() {
  case "${RUNNER_OS:-$(uname)}" in
    Linux) ldd "$1" || true ;;
    macOS|Darwin) otool -L "$1" || true ;;
    Windows) ldd "$1" || true ;;
  esac
}

# Test a solver by running it on the test problem
# Usage: test_solver <solver_name> [solver_path] [quiet]
# Arguments:
#   solver           Name of the solver to test
#   solver_path      Path to the solvers. If not set, use system path
#   quiet            If set to true, print only a version and supress the test output (produce only a return code)
test_solver() {
  SOLVER="$1"

  SOLVER_PREFIX=${2:-}

  if [[ -n "$SOLVER_PREFIX" ]]; then
    SOLVER_PREFIX=$SOLVER_PREFIX/
  fi

  QUIET=${3:-false}

  $QUIET || printf "Testing %s with %s...\n" "$SOLVER" "$PROBLEM"

  # Run the solver and capture output
  case "$SOLVER" in
    abc)
      if $QUIET; then
        RESULT=$(${SOLVER_PREFIX}$SOLVER$EXT -S "%blast; &sweep -C 5000; &syn4; &cec -m -s" < "$PROBLEM" 2>/dev/null)
      else
        if [[ -n "$SOLVER_PREFIX" ]]; then
          deps ${SOLVER_PREFIX}$SOLVER$EXT
        fi
        RESULT=$(${SOLVER_PREFIX}$SOLVER$EXT -S "%blast; &sweep -C 5000; &syn4; &cec -m -s" < "$PROBLEM")
      fi
      ;;
    bitwuzla)
      printf "bitwuzla %s\n" $(${SOLVER_PREFIX}"$SOLVER"$EXT --version)
      # Most solvers use the same invocation pattern
      if $QUIET; then
        RESULT=$(${SOLVER_PREFIX}"$SOLVER"$EXT "$PROBLEM" 2>/dev/null)
      else
        if [[ -n "$SOLVER_PREFIX" ]]; then
          deps ${SOLVER_PREFIX}$SOLVER$EXT
        fi
        RESULT=$(${SOLVER_PREFIX}"$SOLVER"$EXT "$PROBLEM")
      fi
      ;;
    boolector)
      printf "boolector %s\n" $(${SOLVER_PREFIX}$SOLVER$EXT --version)
      if $QUIET; then
        RESULT=$(${SOLVER_PREFIX}$SOLVER$EXT "$PROBLEM" --no-exit-codes 2>/dev/null)
      else
        if [[ -n "$SOLVER_PREFIX" ]]; then
          deps ${SOLVER_PREFIX}$SOLVER$EXT
        fi
        RESULT=$(${SOLVER_PREFIX}$SOLVER$EXT "$PROBLEM" --no-exit-codes)
      fi
      ;;
    yices)
      ${SOLVER_PREFIX}yices-smt2$EXT --version | head -1
      if $QUIET; then
        RESULT=$(${SOLVER_PREFIX}yices-smt2$EXT "$PROBLEM" 2>/dev/null)
      else
        if [[ -n "$SOLVER_PREFIX" ]]; then
          deps ${SOLVER_PREFIX}yices-smt2$EXT
        fi
        RESULT=$(${SOLVER_PREFIX}yices-smt2$EXT "$PROBLEM")
      fi
      ;;
    *)
      ${SOLVER_PREFIX}"$SOLVER"$EXT --version | head -1
      # Most solvers use the same invocation pattern
      if $QUIET; then
        RESULT=$(${SOLVER_PREFIX}"$SOLVER"$EXT "$PROBLEM" 2>/dev/null)
      else
        if [[ -n "$SOLVER_PREFIX" ]]; then
          deps ${SOLVER_PREFIX}$SOLVER$EXT
        fi
        RESULT=$(${SOLVER_PREFIX}"$SOLVER"$EXT "$PROBLEM")
      fi
      ;;
  esac

  # Check if the result contains "unsat"
  if printf "%s" "$RESULT" | grep -q "unsat"; then
    $QUIET || printf "✓ Test passed for %s (returned unsat)\n" "$SOLVER"
  else
    if ! $QUIET; then
      printf "✗ Test failed for %s: expected 'unsat', got:\n" "$SOLVER"
      printf "%s\n" "$RESULT"
    fi
    return 1
  fi
}

# Test all solvers, assume they are on the system PATH
# If the first argument is `quiet`, only the solver version is printed
test_all_solvers() {
  for solver in abc bitwuzla boolector cvc4 cvc5 yices z3-4.8.8 z3-4.8.14
  do
    test_solver "$solver" "" ${1:-}
  done
}

COMMAND="$1"
shift

"$COMMAND" "$@"
