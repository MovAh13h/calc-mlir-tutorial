#include "CalcDialect.h"

using namespace mlir;
using namespace mlir::calc;

#include "CalcDialect.cpp.inc"

#define GET_OP_CLASSES
#include "CalcOps.cpp.inc"

// -----------------------------------------------------------------------------
// Canonicalization patterns generated from CalcPatterns.td.
// The include must be inside an anonymous namespace so the generated
// pattern classes don't conflict with anything else in the linker.
// -----------------------------------------------------------------------------
namespace {
#include "CalcCanonicalize.inc"
} // namespace

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

// =============================================================================
// TASK 2: implement the two canonicalization hooks below.
//
// MLIR auto-generates a method on each op with `let hasCanonicalizer = 1`:
//
//     void Op::getCanonicalizationPatterns(RewritePatternSet &results,
//                                          MLIRContext *context);
//
// The body adds RewritePattern instances to `results`. The patterns
// we want come from CalcPatterns.td via the generated header above,
// and are named AddZero / MulOne / MulZero (the `def NAME` from the
// .td).
//
// API:
//     results.add<P1, P2, ...>(context);  // adds patterns
//
// For AddOp::getCanonicalizationPatterns, add `AddZero`.
// For MulOp::getCanonicalizationPatterns, add `MulOne` and `MulZero`.
//
// NOTE: this Task is technically Task 3 in the README sequence
// (after also adding `let hasCanonicalizer = 1;` to AddOp and MulOp
// in CalcDialect.td — Task 2 of the README). All three changes are
// required for the test to pass.
// =============================================================================

// TODO: write AddOp::getCanonicalizationPatterns and
//             MulOp::getCanonicalizationPatterns here.
