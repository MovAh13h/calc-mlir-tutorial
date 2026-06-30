#!/usr/bin/env bash
# Test runner for stage 11.
#
# Usage:
#   run_jit.sh <calc-opt-path> <mlir-cpu-runner-path> <FileCheck-path> \
#              <input.mlir> [extra calc-opt args...]
#
# What it does:
#   1. Runs `calc-opt [args] input.mlir` — produces LLVM-dialect IR.
#   2. Pipes that to `mlir-cpu-runner -e main --entry-point-result=void`,
#      which JIT-compiles and executes it. printf calls land on stdout.
#   3. Pipes the program's stdout to `FileCheck input.mlir`, matching
#      against the `// CHECK*` directives in the source.
#
# Exits 0 iff every CHECK directive matched the program's stdout.
set -euo pipefail

CALC_OPT="$1"
CPU_RUNNER="$2"
FILECHECK="$3"
SRC="$4"
shift 4

"$CALC_OPT" "$@" "$SRC" |
  "$CPU_RUNNER" -e main --entry-point-result=void |
  "$FILECHECK" "$SRC"
