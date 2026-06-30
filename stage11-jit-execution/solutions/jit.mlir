// End-to-end JIT execution test.
//
// Pipeline (from BUILD.bazel):
//     --calc-to-arith --calc-print-to-llvm
//     --convert-arith-to-llvm --convert-func-to-llvm
//     --reconcile-unrealized-casts
//
// The lowered IR is then handed to mlir-cpu-runner, which JIT-compiles
// it (printf is linked from the host libc) and invokes @main. The CHECK
// directives below match against the program's *stdout*, not the IR.
//
// Expected output (one number per line — the calc.print → printf format
// string is "%d\n"):
//
//   2
//   7
//   42

// CHECK: 2
// CHECK: 7
// CHECK: 42
func.func @main() {
  // 2.
  %two = calc.const 2 : i32
  calc.print %two : i32

  // 3 + 4 = 7.
  %a = calc.const 3 : i32
  %b = calc.const 4 : i32
  %sum = calc.add %a, %b : i32
  calc.print %sum : i32

  // 6 * 7 = 42.
  %c = calc.const 6 : i32
  %d = calc.const 7 : i32
  %prod = calc.mul %c, %d : i32
  calc.print %prod : i32

  return
}
