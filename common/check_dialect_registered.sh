#!/usr/bin/env bash
# Usage: check_dialect_registered.sh <calc-opt-path> <dialect-name>
#
# Asserts that the given mlir-opt-style binary reports <dialect-name>
# when invoked with --show-dialects. Output format from mlir-opt is:
#
#     Available Dialects: acc,affine,arith,...,calc,...
#
# We split on commas/whitespace and look for an exact match.
set -euo pipefail

OPT="$1"
DIALECT="$2"

DIALECTS=$("$OPT" --show-dialects | tr ',:' '\n' | tr -d ' ')
if ! echo "$DIALECTS" | grep -qx "$DIALECT"; then
  echo "FAIL: dialect '$DIALECT' not registered."
  echo "Available dialects:"
  echo "$DIALECTS" | sed 's/^/  /'
  exit 1
fi
echo "OK: dialect '$DIALECT' is registered."
