// -----------------------------------------------------------------------------
// Stage 00 — Hello MLIR
//
// Two tiny functions. Edit the bodies so the CHECK directives match
// `mlir-opt`'s output for this file.
//
// Run:
//   bazel test //stage00-hello-mlir/code:hello_test
// -----------------------------------------------------------------------------

// =============================================================================
// Task 1: make `main` return the constant 42 as i32.
// (Currently returns 0 — change it.)
// =============================================================================

// CHECK-LABEL: func.func @main
// CHECK-SAME:    () -> i32
// CHECK:         %[[C:.*]] = arith.constant 42 : i32
// CHECK:         return %[[C]] : i32
func.func @main() -> i32 {
  // TODO: replace 0 with 42
  %0 = arith.constant 0 : i32
  return %0 : i32
}

// =============================================================================
// Task 2: implement `add_five(%x) = %x + 5`.
// =============================================================================

// CHECK-LABEL: func.func @add_five
// CHECK-SAME:    (%[[X:.*]]: i32) -> i32
// CHECK:         %[[C5:.*]] = arith.constant 5 : i32
// CHECK:         %[[SUM:.*]] = arith.addi %[[X]], %[[C5]] : i32
// CHECK:         return %[[SUM]] : i32
func.func @add_five(%x: i32) -> i32 {
  // TODO: produce %x + 5 and return it.
  // Hint: arith.constant for the literal, arith.addi for the addition.
  return %x : i32
}
