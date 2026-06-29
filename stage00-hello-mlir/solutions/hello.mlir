// -----------------------------------------------------------------------------
// Stage 00 — Hello MLIR — solution
// -----------------------------------------------------------------------------

// CHECK-LABEL: func.func @main
// CHECK-SAME:    () -> i32
// CHECK:         %[[C:.*]] = arith.constant 42 : i32
// CHECK:         return %[[C]] : i32
func.func @main() -> i32 {
  %0 = arith.constant 42 : i32
  return %0 : i32
}

// CHECK-LABEL: func.func @add_five
// CHECK-SAME:    (%[[X:.*]]: i32) -> i32
// CHECK:         %[[C5:.*]] = arith.constant 5 : i32
// CHECK:         %[[SUM:.*]] = arith.addi %[[X]], %[[C5]] : i32
// CHECK:         return %[[SUM]] : i32
func.func @add_five(%x: i32) -> i32 {
  %c5 = arith.constant 5 : i32
  %sum = arith.addi %x, %c5 : i32
  return %sum : i32
}
