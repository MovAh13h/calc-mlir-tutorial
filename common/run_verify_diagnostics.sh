#!/usr/bin/env bash
# Usage: run_verify_diagnostics.sh <calc-opt-path> <input.mlir>
#
# Runs `calc-opt --verify-diagnostics --split-input-file <input>`.
# In this mode, MLIR walks the input looking for `// expected-error`,
# `// expected-warning`, `// expected-remark`, and `// expected-note`
# directives, then checks that the diagnostics they describe are
# actually emitted at the right source locations.
#
# Exits 0 if every expected diagnostic fired AND no unexpected
# diagnostics escaped. Nonzero otherwise. This is *the* idiomatic
# MLIR way to test verifier errors and other diagnostics.
#
# --split-input-file lets one .mlir file hold multiple independent
# snippets separated by `// -----` lines; each snippet is verified on
# its own.
set -euo pipefail

OPT="$1"
SRC="$2"

"$OPT" --verify-diagnostics --split-input-file "$SRC" > /dev/null
