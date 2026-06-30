// End-to-end JIT execution.
//
// Pipeline (already wired in BUILD.bazel):
//     --calc-to-arith --calc-print-to-llvm
//     --convert-arith-to-llvm --convert-func-to-llvm
//     --reconcile-unrealized-casts
//
// The lowered IR is handed to mlir-cpu-runner, which JIT-compiles it
// (printf is linked from the host libc) and invokes @main. The CHECK
// directives below match against the program's *stdout*, not the IR.
//
// TODO — fill in CHECK lines.
//
// Each calc.print emits one number per line (the format string is "%d\n").
// Run the pipeline interactively (see README) to confirm what you expect,
// then translate that into CHECK directives. Order matters — CHECK matches
// in sequence.

// TODO: CHECK directives go here.

func.func @main() {
  // Hint: one calc.print per CHECK line.
  %two = calc.const 2 : i32
  calc.print %two : i32

  %a = calc.const 3 : i32
  %b = calc.const 4 : i32
  %sum = calc.add %a, %b : i32
  calc.print %sum : i32

  %c = calc.const 6 : i32
  %d = calc.const 7 : i32
  %prod = calc.mul %c, %d : i32
  calc.print %prod : i32

  return
}
