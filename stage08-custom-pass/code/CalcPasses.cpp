#include "CalcPasses.h"

#include "mlir/IR/PatternMatch.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"

namespace mlir {
namespace calc {

// Expands to the pass base class definition. Must come AFTER the
// include of `CalcPasses.h.inc` (which `CalcPasses.h` pulls in) and
// BEFORE any class that inherits from `impl::CalcStrengthReduceBase`.
#define GEN_PASS_DEF_CALCSTRENGTHREDUCE
#include "CalcPasses.h.inc"

namespace {

// -----------------------------------------------------------------------------
// TODO (Task 3) — write the rewrite pattern body.
//
// Implement `matchAndRewrite` to:
//   1. Return failure() if the RHS isn't a constant equal to 2.
//   2. Otherwise replace the MulOp with an AddOp of (lhs, lhs).
//
// Tips:
//   - `matchPattern(op.getRhs(), m_Constant(&attr))` binds the
//     constant attribute if the RHS is a ConstantLike op. We made
//     calc.const ConstantLike in stage 07.
//   - Use `IntegerAttr` as the bound type and call `.getInt()`.
//   - Use `rewriter.replaceOpWithNewOp<AddOp>(op, op.getType(),
//     op.getLhs(), op.getLhs())` to commit the rewrite.
//   - Commutative trait normalises constants to RHS, so you do NOT
//     need to handle `mul (const 2), x` separately — the greedy
//     driver will swap operands first.
// -----------------------------------------------------------------------------
struct MulByTwoToAdd : public OpRewritePattern<MulOp> {
  using OpRewritePattern<MulOp>::OpRewritePattern;

  LogicalResult matchAndRewrite(MulOp op,
                                PatternRewriter &rewriter) const override {
    // TODO: implement.
    return failure();
  }
};

// -----------------------------------------------------------------------------
// TODO (Task 4) — implement runOnOperation().
//
// Build a `RewritePatternSet`, add `MulByTwoToAdd` to it, then call
// `applyPatternsAndFoldGreedily(getOperation(), std::move(patterns))`.
// If that fails, call `signalPassFailure()`.
// -----------------------------------------------------------------------------
struct CalcStrengthReducePass
    : public impl::CalcStrengthReduceBase<CalcStrengthReducePass> {
  void runOnOperation() override {
    // TODO: implement.
  }
};

} // namespace

std::unique_ptr<Pass> createCalcStrengthReducePass() {
  return std::make_unique<CalcStrengthReducePass>();
}

} // namespace calc
} // namespace mlir
