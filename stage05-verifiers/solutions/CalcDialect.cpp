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

// -----------------------------------------------------------------------------
// Custom verifier for calc.shr.
//
// Returns success() if the op is well-formed, or emits a diagnostic
// and returns failure() if not. emitOpError() automatically prefixes
// the op's name and location.
// -----------------------------------------------------------------------------
LogicalResult ShrOp::verify() {
  // If the shift amount comes from a constant we can check statically,
  // ensure it fits in [0, 31]. Otherwise it's a dynamic value and we
  // can only trust the user (or hope a later pass folds it).
  auto cst = getAmount().getDefiningOp<ConstOp>();
  if (!cst)
    return success();

  uint32_t v = cst.getValue();
  if (v > 31)
    return emitOpError("shift amount must be in [0, 31], got ") << v;

  return success();
}
