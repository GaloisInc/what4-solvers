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
BIN="${BIN:-$TOP/bin}"
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
# Usage: test_solver <solver_name> [use_system_path]
# Arguments:
#   solver_name      Name of the solver to test
#   use_system_path  If "true", use solvers from system PATH instead of local ./bin directory
test_solver() {
  SOLVER="$1"
  USE_SYSTEM_PATH="${2:-false}"
  echo "Testing $SOLVER with $PROBLEM..."

  if $USE_SYSTEM_PATH; then
    # Use solvers from system PATH
    SOLVER_PREFIX=""
  else
    # Use solvers from local bin directory
    cd "$BIN"
    SOLVER_PREFIX="./"
  fi

  # Run the solver and capture output
  case "$SOLVER" in
    abc)
      RESULT=$(deps ${SOLVER_PREFIX}abc$EXT && ${SOLVER_PREFIX}abc$EXT -S "%blast; &sweep -C 5000; &syn4; &cec -m -s" < "$PROBLEM")
      ;;
    boolector)
      RESULT=$(${SOLVER_PREFIX}boolector$EXT --version && deps ${SOLVER_PREFIX}boolector$EXT && ${SOLVER_PREFIX}boolector$EXT "$PROBLEM" --no-exit-codes)
      ;;
    yices)
      RESULT=$(${SOLVER_PREFIX}yices-smt2$EXT --version && deps ${SOLVER_PREFIX}yices-smt2$EXT && ${SOLVER_PREFIX}yices-smt2$EXT "$PROBLEM")
      ;;
    *)
      # Most solvers use the same invocation pattern
      RESULT=$(${SOLVER_PREFIX}"$SOLVER"$EXT --version && deps ${SOLVER_PREFIX}"$SOLVER"$EXT && ${SOLVER_PREFIX}"$SOLVER"$EXT "$PROBLEM")
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

# Test all solvers, assume they are on the PATH
test_all_solvers() {
  for solver in abc bitwuzla boolector cvc4 cvc5 yices z3-4.8.8 z3-4.8.14
  do
    which "$solver"
    test_solver "$solver" true
  done
}
