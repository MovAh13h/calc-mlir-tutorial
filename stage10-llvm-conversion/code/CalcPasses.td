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
// TODO (Task 1) — declare CalcPrintToLLVM.
//
//   def CalcPrintToLLVM
//       : Pass<"calc-print-to-llvm", "::mlir::ModuleOp"> {
//     let summary = "Lower calc.print to llvm.call @printf.";
//     let constructor = "::mlir::calc::createCalcPrintToLLVMPass()";
//     let dependentDialects = ["::mlir::LLVM::LLVMDialect"];
//   }
//
// `dependentDialects` MUST include LLVMDialect — the pass emits
// llvm.* ops, and the LLVM dialect must be loaded before they can
// be created.
// =============================================================================

#endif // CALC_PASSES_TD
