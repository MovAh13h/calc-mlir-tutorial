#ifndef CALC_PASSES_TD
#define CALC_PASSES_TD

include "mlir/Pass/PassBase.td"

// =============================================================================
// CalcStrengthReduce — from stage 08.
// =============================================================================
def CalcStrengthReduce
    : Pass<"calc-strength-reduce", "::mlir::func::FuncOp"> {
  let summary = "Replace `mul x, 2` with `add x, x`.";
  let constructor = "::mlir::calc::createCalcStrengthReducePass()";
  let dependentDialects = ["::mlir::calc::CalcDialect"];
}

// =============================================================================
// CalcToArith — from stage 09.
// =============================================================================
def CalcToArith : Pass<"calc-to-arith", "::mlir::ModuleOp"> {
  let summary = "Lower calc arithmetic ops to the arith dialect.";
  let constructor = "::mlir::calc::createCalcToArithPass()";
  let dependentDialects = ["::mlir::arith::ArithDialect"];
}

// =============================================================================
// CalcPrintToLLVM — lower calc.print to llvm.call @printf.
//
// This pass:
//   1. Inserts an `llvm.func @printf(!llvm.ptr, ...) -> i32` external
//      declaration into the module, if not already present.
//   2. Inserts an `llvm.mlir.global internal constant @calc_print_fmt`
//      holding the string `"%d\n\0"`.
//   3. Rewrites each `calc.print %x : i32` to:
//        %fmt = llvm.mlir.addressof @calc_print_fmt : !llvm.ptr
//        llvm.call @printf(%fmt, %x) : (!llvm.ptr, i32) -> i32
//
// After this pass + --convert-arith-to-llvm + --convert-func-to-llvm
// (+ --reconcile-unrealized-casts to clean up the func/llvm boundary),
// the module is in pure LLVM dialect — ready for mlir-translate or
// mlir-cpu-runner.
// =============================================================================
def CalcPrintToLLVM
    : Pass<"calc-print-to-llvm", "::mlir::ModuleOp"> {
  let summary = "Lower calc.print to llvm.call @printf.";
  let description = [{
    Inserts printf and a "%d\n" format string into the module, then
    converts every calc.print into the corresponding llvm.call. After
    this pass calc is fully eliminated; chain with --convert-arith-to-llvm
    and --convert-func-to-llvm to reach pure LLVM dialect IR.
  }];
  let constructor = "::mlir::calc::createCalcPrintToLLVMPass()";
  let dependentDialects = ["::mlir::LLVM::LLVMDialect"];
}

#endif // CALC_PASSES_TD
