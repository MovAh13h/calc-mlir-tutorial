#!/usr/bin/env bash
# Test runner used by every stage's tests.
#
# Usage:
#   run_filecheck.sh <mlir-opt-path> <FileCheck-path> <input.mlir> [extra mlir-opt args...]
#
# What it does:
#   1. Runs `mlir-opt [args] input.mlir`.
#   2. Pipes the output to `FileCheck input.mlir`, which looks for
#      `// CHECK*` directives in the same input file and verifies they
#      match the output line-by-line.
#
# Exits 0 if all CHECKs match, nonzero otherwise.
set -euo pipefail

MLIR_OPT="$1"
FILECHECK="$2"
SRC="$3"
shift 3

"$MLIR_OPT" "$@" "$SRC" | "$FILECHECK" "$SRC"
