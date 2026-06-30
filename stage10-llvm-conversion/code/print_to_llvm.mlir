// Just the calc.print → llvm.call lowering. Run with --calc-print-to-llvm.
//
// Only calc.print is converted; everything else (calc.const, arith ops,
// func ops) is left alone for this test.

// CHECK: llvm.mlir.global internal constant @calc_print_fmt("%d\0A\00")
// CHECK: llvm.func @printf(!llvm.ptr, ...) -> i32

// CHECK-LABEL: func.func @uses_print
// CHECK:         %[[V:.*]] = arith.constant 42 : i32
// CHECK:         %[[A:.*]] = llvm.mlir.addressof @calc_print_fmt
// CHECK:         %[[F:.*]] = llvm.bitcast %[[A]]
// CHECK-SAME:                  to !llvm.ptr
// CHECK:         llvm.call @printf(%[[F]], %[[V]])
// CHECK-NOT:     calc.print
func.func @uses_print() {
  %v = arith.constant 42 : i32
  calc.print %v : i32
  return
}

// A second user — the pass should reuse the same printf decl and
// format string global (we already only emit them once per module).
// CHECK-LABEL: func.func @uses_print_again
// CHECK:         llvm.call @printf
func.func @uses_print_again(%x: i32) {
  calc.print %x : i32
  return
}
