#ifndef CALC_DIALECT_TD
#define CALC_DIALECT_TD

include "mlir/IR/OpBase.td"

// =============================================================================
// TASK: declare the `calc` dialect.
//
// You need a `def Calc_Dialect : Dialect { ... }` block that sets three
// fields:
//
//   let name          = "calc";
//   let summary       = "<a short one-liner>";
//   let cppNamespace  = "::mlir::calc";
//
// `cppNamespace` must be exactly `::mlir::calc` because CalcDialect.cpp
// and CalcDialect.h reference `mlir::calc::CalcDialect`. If you change
// the namespace, the build breaks.
//
// `name` is what users will type in .mlir files (e.g. `calc.const`).
// `summary` shows up in `--help`-style output and dialect documentation.
//
// When you're done, run:
//   bazel test //stage01-empty-dialect/code:calc_dialect_registered_test
//
// If you get stuck, see solutions/CalcDialect.td.
// =============================================================================

// TODO: write `def Calc_Dialect : Dialect { ... }` here.

#endif // CALC_DIALECT_TD
