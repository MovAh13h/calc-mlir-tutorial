#ifndef CALC_DIALECT_TD
#define CALC_DIALECT_TD

include "mlir/IR/OpBase.td"

// Defines our dialect via ODS.
//
// `mlir-tblgen` consumes this and generates two C++ files:
//   - CalcDialect.h.inc — class declaration for CalcDialect
//   - CalcDialect.cpp.inc — class definition (constructor, name(), etc.)
def Calc_Dialect : Dialect {
  let name = "calc";
  let summary = "A tutorial dialect for arithmetic over i32.";
  let cppNamespace = "::mlir::calc";
}

#endif // CALC_DIALECT_TD
