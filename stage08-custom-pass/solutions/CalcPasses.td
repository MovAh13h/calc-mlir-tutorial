#ifndef CALC_PASSES_TD
#define CALC_PASSES_TD

include "mlir/Pass/PassBase.td"

// =============================================================================
// CalcStrengthReduce — replace `calc.mul x, (calc.const 2)` with
// `calc.add x, x`.
//
// `Pass<"flag-name", "op-name">` declares a pass that runs on every op of
// the given type. Here we choose `func::FuncOp` so the pass walks each
// function body. Choosing a more specific op type means the pass driver
// only invokes us on those ops (and we don't have to filter ourselves).
//
// `let constructor = ...` says "to instantiate this pass, call this C++
// factory function." `gen-pass-decls` will register the pass under the
// declared name and use that factory.
//
// `let dependentDialects = ...` declares dialects that must be loaded
// before the pass runs, even if the input IR doesn't already reference
// them. We don't introduce any *new* dialects here (only calc.add, which
// is calc, already loaded), but listing CalcDialect anyway is a no-cost
// safety net.
// =============================================================================
def CalcStrengthReduce
    : Pass<"calc-strength-reduce", "::mlir::func::FuncOp"> {
  let summary = "Replace `mul x, 2` with `add x, x`.";
  let description = [{
    A toy strength-reduction pass: rewrites `calc.mul %x, (calc.const 2)`
    into `calc.add %x, %x`. Demonstrates the mechanics of writing,
    registering, and running a custom pass — not actually useful (the
    canonicalizer would constant-fold `calc.const 2 * 4` already, and
    real codegen would do this lowering at the LLVM level).
  }];
  let constructor = "::mlir::calc::createCalcStrengthReducePass()";
  let dependentDialects = ["::mlir::calc::CalcDialect"];
}

#endif // CALC_PASSES_TD
