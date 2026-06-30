#ifndef CALC_PASSES_TD
#define CALC_PASSES_TD

include "mlir/Pass/PassBase.td"

// =============================================================================
// TODO (Task 1) — declare the CalcStrengthReduce pass.
//
// You need a `def` of the form:
//
//   def CalcStrengthReduce
//       : Pass<"calc-strength-reduce", "::mlir::func::FuncOp"> {
//     let summary = "...";
//     let constructor = "::mlir::calc::createCalcStrengthReducePass()";
//     let dependentDialects = ["::mlir::calc::CalcDialect"];
//   }
//
// Notes:
//   - First arg to `Pass<>` is the CLI flag name (without `--`).
//   - Second arg is the op type the pass is anchored on. We use
//     `func::FuncOp` so the pass runs once per function in the module.
//   - `constructor` is the C++ factory called when the pass is
//     instantiated. The string must match the name you'll give the
//     factory in CalcPasses.cpp.
// =============================================================================

#endif // CALC_PASSES_TD
