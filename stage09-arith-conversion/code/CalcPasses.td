#ifndef CALC_PASSES_TD
#define CALC_PASSES_TD

include "mlir/Pass/PassBase.td"

// =============================================================================
// CalcStrengthReduce — carried over from stage 08.
// =============================================================================
def CalcStrengthReduce
    : Pass<"calc-strength-reduce", "::mlir::func::FuncOp"> {
  let summary = "Replace `mul x, 2` with `add x, x`.";
  let constructor = "::mlir::calc::createCalcStrengthReducePass()";
  let dependentDialects = ["::mlir::calc::CalcDialect"];
}

// =============================================================================
// TODO (Task 1) — declare the CalcToArith pass.
//
// Add a pass similar to the one above:
//   - flag name: "calc-to-arith"
//   - anchor: "::mlir::ModuleOp"   (run once for the whole module)
//   - constructor: "::mlir::calc::createCalcToArithPass()"
//   - dependentDialects: ["::mlir::arith::ArithDialect"]
//
// `dependentDialects` is REQUIRED here because the pass *emits* arith
// ops. Without that, the arith dialect might not be loaded when the
// pass tries to create an `arith::AddIOp`, and you'll get a crash.
// =============================================================================

#endif // CALC_PASSES_TD
