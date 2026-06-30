// End-to-end pipeline: calc → arith → LLVM.
//
// Pipeline (set in BUILD.bazel for this test):
//     --calc-to-arith
//     --calc-print-to-llvm
//     --convert-arith-to-llvm
//     --convert-func-to-llvm
//     --reconcile-unrealized-casts
//
// After all of that, the module should contain only LLVM dialect ops
// (plus the printf decl + format string global).

// CHECK: llvm.mlir.global internal constant @calc_print_fmt("%d\0A\00")
// CHECK: llvm.func @printf(!llvm.ptr, ...) -> i32

// CHECK-NOT: calc.
// CHECK-NOT: arith.
// CHECK-NOT: func.

// CHECK-LABEL: llvm.func @main
// CHECK:         llvm.mlir.constant
// CHECK:         llvm.add
// CHECK:         llvm.mul
// CHECK:         llvm.mlir.addressof @calc_print_fmt
// CHECK:         llvm.call @printf
// CHECK:         llvm.return
func.func @main(%x: i32, %y: i32) {
  %c2 = calc.const 2 : i32
  %s  = calc.add %x, %c2 : i32
  %r  = calc.mul %s, %y : i32
  calc.print %r : i32
  return
}
