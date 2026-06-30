#include "CalcPasses.h"

#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Transforms/DialectConversion.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"

namespace mlir {
namespace calc {

#define GEN_PASS_DEF_CALCSTRENGTHREDUCE
#define GEN_PASS_DEF_CALCTOARITH
#include "CalcPasses.h.inc"

// =============================================================================
// Strength-reduction pass (from stage 08, unchanged).
// =============================================================================
namespace {

struct MulByTwoToAdd : public OpRewritePattern<MulOp> {
  using OpRewritePattern<MulOp>::OpRewritePattern;
  LogicalResult matchAndRewrite(MulOp op,
                                PatternRewriter &rewriter) const override {
    IntegerAttr rhsAttr;
    if (!matchPattern(op.getRhs(), m_Constant(&rhsAttr)))
      return failure();
    if (rhsAttr.getInt() != 2)
      return failure();
    rewriter.replaceOpWithNewOp<AddOp>(op, op.getType(), op.getLhs(),
                                       op.getLhs());
    return success();
  }
};

struct CalcStrengthReducePass
    : public impl::CalcStrengthReduceBase<CalcStrengthReducePass> {
  void runOnOperation() override {
    RewritePatternSet patterns(&getContext());
    patterns.add<MulByTwoToAdd>(&getContext());
    if (failed(applyPatternsAndFoldGreedily(getOperation(),
                                            std::move(patterns))))
      signalPassFailure();
  }
};

} // namespace

std::unique_ptr<Pass> createCalcStrengthReducePass() {
  return std::make_unique<CalcStrengthReducePass>();
}

// =============================================================================
// CalcToArith — TODO (Tasks 2–4).
//
// Conversion is more structured than a plain RewritePattern run:
//   1. A `ConversionTarget` declares which ops/dialects are LEGAL in
//      the output vs ILLEGAL (must be rewritten away).
//   2. `OpConversionPattern<OpTy>` patterns specify how to rewrite
//      illegal ops into legal ones.
//   3. `applyPartialConversion` walks the IR, applies patterns to all
//      illegal ops, and succeeds as long as no illegal op survives.
//
// Why OpConversionPattern, not OpRewritePattern? Conversion runs in
// "blue/green" mode — operand types may be remapped by a TypeConverter.
// Patterns receive an `OpAdaptor` whose `getX()` methods return the
// REMAPPED operand values. Our types are all i32 (identity remap),
// but the framework is set up for the general case.
// =============================================================================
namespace {

// TODO (Task 2) — one OpConversionPattern per illegal op.
//
// Skeleton:
//
//   struct ConstOpLowering : public OpConversionPattern<ConstOp> {
//     using OpConversionPattern<ConstOp>::OpConversionPattern;
//     LogicalResult matchAndRewrite(
//         ConstOp op, OpAdaptor adaptor,
//         ConversionPatternRewriter &rewriter) const override {
//       rewriter.replaceOpWithNewOp<arith::ConstantOp>(
//           op, op.getType(), op.getValueAttr());
//       return success();
//     }
//   };
//
// Add four patterns:
//   ConstOpLowering : calc.const  → arith.constant (use op.getValueAttr())
//   AddOpLowering   : calc.add    → arith.AddIOp
//   MulOpLowering   : calc.mul    → arith.MulIOp
//   ShrOpLowering   : calc.shr    → arith.ShRUIOp   (unsigned/logical)
//
// For the binary ops, get operands via `adaptor.getLhs()` etc. — the
// adaptor returns the post-remap operands and is what you must use in
// conversion patterns.

// TODO (Task 3) — implement the pass class:
//
//   struct CalcToArithPass : public impl::CalcToArithBase<CalcToArithPass> {
//     void runOnOperation() override {
//       ConversionTarget target(getContext());
//       target.addLegalDialect<arith::ArithDialect, func::FuncDialect>();
//       target.addIllegalDialect<CalcDialect>();
//       target.addLegalOp<PrintOp>();   // keep calc.print until stage 10
//
//       RewritePatternSet patterns(&getContext());
//       patterns.add<ConstOpLowering, AddOpLowering, MulOpLowering,
//                    ShrOpLowering>(&getContext());
//
//       if (failed(applyPartialConversion(getOperation(), target,
//                                         std::move(patterns))))
//         signalPassFailure();
//     }
//   };
//
// Order matters: `addLegalOp<PrintOp>` AFTER `addIllegalDialect<CalcDialect>`
// — the later call wins. If you reverse the order, calc.print stays
// illegal and the conversion will fail because no pattern handles it.

} // namespace

// TODO (Task 4) — provide the factory:
//
//   std::unique_ptr<Pass> createCalcToArithPass() {
//     return std::make_unique<CalcToArithPass>();
//   }
//
// CalcPasses.h already declares this; ODS-generated registration in
// CalcPasses.td references it by name.

} // namespace calc
} // namespace mlir
