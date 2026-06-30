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
// CalcToArith — partial dialect conversion.
//
// Conversion is more structured than a plain RewritePattern run:
//   1. A `ConversionTarget` declares which ops/dialects are LEGAL in
//      the output (allowed to remain) vs ILLEGAL (must be rewritten).
//   2. `OpConversionPattern<OpTy>` patterns specify how to rewrite
//      illegal ops into legal ones.
//   3. `applyPartialConversion` walks the IR, applies patterns to all
//      illegal ops, and SUCCEEDS as long as no illegal op survives.
//      (Partial: legal ops are fine; full: every op must be in the
//      legal set, even those that were already legal — typically used
//      at the final lowering step.)
//
// Why OpConversionPattern, not OpRewritePattern? Because conversion
// runs in "blue/green" mode — operand types may be remapped by a
// TypeConverter, so the patterns receive an `OpAdaptor` whose
// `getX()` methods return the REMAPPED operand values, not the
// pre-conversion ones. Our types are all i32, so the remap is the
// identity, but the framework is set up for the general case.
// =============================================================================
namespace {

// calc.const N : i32  →  arith.constant N : i32
struct ConstOpLowering : public OpConversionPattern<ConstOp> {
  using OpConversionPattern<ConstOp>::OpConversionPattern;
  LogicalResult matchAndRewrite(ConstOp op, OpAdaptor adaptor,
                                ConversionPatternRewriter &rewriter)
      const override {
    rewriter.replaceOpWithNewOp<arith::ConstantOp>(op, op.getType(),
                                                   op.getValueAttr());
    return success();
  }
};

// calc.add %a, %b  →  arith.addi %a, %b
struct AddOpLowering : public OpConversionPattern<AddOp> {
  using OpConversionPattern<AddOp>::OpConversionPattern;
  LogicalResult matchAndRewrite(AddOp op, OpAdaptor adaptor,
                                ConversionPatternRewriter &rewriter)
      const override {
    rewriter.replaceOpWithNewOp<arith::AddIOp>(op, adaptor.getLhs(),
                                               adaptor.getRhs());
    return success();
  }
};

// calc.mul %a, %b  →  arith.muli %a, %b
struct MulOpLowering : public OpConversionPattern<MulOp> {
  using OpConversionPattern<MulOp>::OpConversionPattern;
  LogicalResult matchAndRewrite(MulOp op, OpAdaptor adaptor,
                                ConversionPatternRewriter &rewriter)
      const override {
    rewriter.replaceOpWithNewOp<arith::MulIOp>(op, adaptor.getLhs(),
                                               adaptor.getRhs());
    return success();
  }
};

// calc.shr %x, %amt  →  arith.shrui %x, %amt   (logical shift right)
struct ShrOpLowering : public OpConversionPattern<ShrOp> {
  using OpConversionPattern<ShrOp>::OpConversionPattern;
  LogicalResult matchAndRewrite(ShrOp op, OpAdaptor adaptor,
                                ConversionPatternRewriter &rewriter)
      const override {
    rewriter.replaceOpWithNewOp<arith::ShRUIOp>(op, adaptor.getValue(),
                                                adaptor.getAmount());
    return success();
  }
};

struct CalcToArithPass : public impl::CalcToArithBase<CalcToArithPass> {
  void runOnOperation() override {
    ConversionTarget target(getContext());
    // arith and func are fully legal in the output.
    target.addLegalDialect<arith::ArithDialect, func::FuncDialect>();
    // Everything from calc starts illegal: must be rewritten.
    target.addIllegalDialect<CalcDialect>();
    // …except calc.print, which we explicitly mark legal so it
    // survives until stage 10. Order matters: `addLegalOp` after
    // `addIllegalDialect` wins.
    target.addLegalOp<PrintOp>();

    RewritePatternSet patterns(&getContext());
    patterns.add<ConstOpLowering, AddOpLowering, MulOpLowering,
                 ShrOpLowering>(&getContext());

    if (failed(applyPartialConversion(getOperation(), target,
                                      std::move(patterns))))
      signalPassFailure();
  }
};

} // namespace

std::unique_ptr<Pass> createCalcToArithPass() {
  return std::make_unique<CalcToArithPass>();
}

} // namespace calc
} // namespace mlir
