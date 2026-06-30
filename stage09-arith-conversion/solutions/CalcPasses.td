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
// CalcToArith — partial conversion lowering calc arithmetic to arith.
//
// Anchored on ModuleOp so we convert all functions in one invocation.
// `dependentDialects` lists arith because we EMIT arith ops — without
// that, the arith dialect might not be loaded and creating an
// `arith::AddIOp` would crash.
//
// We intentionally leave `calc.print` untouched. It's marked legal in
// the ConversionTarget, so the partial-conversion driver lets it stay.
// Stage 10 lowers print → printf alongside the rest of the way to LLVM.
// =============================================================================
def CalcToArith : Pass<"calc-to-arith", "::mlir::ModuleOp"> {
  let summary = "Lower calc arithmetic ops to the arith dialect.";
  let description = [{
    Partial dialect conversion: `calc.const`, `calc.add`, `calc.mul`,
    `calc.shr` become their arith equivalents. `calc.print` is left
    in place; stage 10 lowers it together with everything else.
  }];
  let constructor = "::mlir::calc::createCalcToArithPass()";
  let dependentDialects = ["::mlir::arith::ArithDialect"];
}

#endif // CALC_PASSES_TD
