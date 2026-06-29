#include "CalcDialect.h"

using namespace mlir;
using namespace mlir::calc;

#include "CalcDialect.cpp.inc"

#define GET_OP_CLASSES
#include "CalcOps.cpp.inc"

void CalcDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "CalcOps.cpp.inc"
      >();
}

// =============================================================================
// TASK 2: implement `ShrOp::verify()`.
//
// Required behaviour:
//   - If the shift amount operand is statically a calc.const, fetch
//     its uint32_t value and ensure it's <= 31. Out-of-range values
//     must report:
//
//         shift amount must be in [0, 31], got <N>
//
//     via `emitOpError(...) << N`.
//
//   - If the shift amount is NOT a constant (it's a dynamic value),
//     return success() — we can't check at compile time.
//
// API hints:
//
//     // operand accessor (auto-generated from ODS):
//     Value Op::getAmount();
//
//     // walk back to the defining op, if any:
//     auto cst = getAmount().getDefiningOp<ConstOp>();
//
//     // ConstOp::getValue() returns uint32_t (auto-generated from
//     // I32Attr):
//     uint32_t v = cst.getValue();
//
//     // emitOpError prefixes the op's name and source location:
//     return emitOpError("shift amount must be in [0, 31], got ") << v;
//
//     // success path:
//     return success();
//
// Return type: LogicalResult.
// =============================================================================

// TODO: implement `LogicalResult ShrOp::verify() { ... }` here.
