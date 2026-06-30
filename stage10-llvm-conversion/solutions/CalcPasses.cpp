#include "CalcPasses.h"

#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Transforms/DialectConversion.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"

namespace mlir {
namespace calc {

#define GEN_PASS_DEF_CALCSTRENGTHREDUCE
#define GEN_PASS_DEF_CALCTOARITH
#define GEN_PASS_DEF_CALCPRINTTOLLVM
#include "CalcPasses.h.inc"

// =============================================================================
// Stage 08 — strength reduction (unchanged).
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
// Stage 09 — calc → arith partial conversion (unchanged).
// =============================================================================
namespace {

struct ConstOpLowering : public OpConversionPattern<ConstOp> {
  using OpConversionPattern<ConstOp>::OpConversionPattern;
  LogicalResult matchAndRewrite(ConstOp op, OpAdaptor,
                                ConversionPatternRewriter &rewriter)
      const override {
    rewriter.replaceOpWithNewOp<arith::ConstantOp>(op, op.getType(),
                                                   op.getValueAttr());
    return success();
  }
};
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
    target.addLegalDialect<arith::ArithDialect, func::FuncDialect>();
    target.addIllegalDialect<CalcDialect>();
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

// =============================================================================
// Stage 10 — calc.print → llvm.call @printf.
//
// Sketch of what we emit:
//
//   llvm.func @printf(!llvm.ptr, ...) -> i32
//   llvm.mlir.global internal constant @calc_print_fmt("%d\n\00")
//
//   func.func @user() {
//     %v = arith.constant 7 : i32
//     %f = llvm.mlir.addressof @calc_print_fmt : !llvm.ptr
//     %_ = llvm.call @printf(%f, %v) vararg(!llvm.func<i32 (ptr, ...)>)
//          : (!llvm.ptr, i32) -> i32
//   }
//
// Notes:
//   - LLVM 17 uses opaque pointers (`!llvm.ptr` with no element type),
//     so we don't need a GEP to get a pointer to the first character —
//     `llvm.mlir.addressof` already returns `!llvm.ptr`.
//   - We add `llvm.func` + `llvm.mlir.global` once per module, the
//     first time the pass sees a `calc.print`. Helper functions
//     `ensurePrintfDecl` and `ensureFormatString` do that.
//   - The pattern is a plain `OpRewritePattern` (not OpConversionPattern)
//     — we aren't remapping types here; the value being printed is
//     still i32. (Stage 11 will run --convert-arith-to-llvm afterwards
//     to push everything else into the LLVM dialect too.)
// =============================================================================
namespace {

static constexpr llvm::StringRef kFormatStringName = "calc_print_fmt";
static constexpr llvm::StringRef kPrintfName = "printf";
// "%d\n" + terminator. Length includes the trailing nul.
static constexpr llvm::StringRef kFormatStringValue("%d\n\0", 4);

static LLVM::LLVMFuncOp ensurePrintfDecl(ModuleOp module) {
  if (auto fn = module.lookupSymbol<LLVM::LLVMFuncOp>(kPrintfName))
    return fn;
  MLIRContext *ctx = module.getContext();
  OpBuilder b(module.getBodyRegion());
  // i32 printf(ptr, ...)
  auto i32 = IntegerType::get(ctx, 32);
  auto ptr = LLVM::LLVMPointerType::get(ctx);
  auto fnType = LLVM::LLVMFunctionType::get(i32, {ptr},
                                            /*isVarArg=*/true);
  return b.create<LLVM::LLVMFuncOp>(module.getLoc(), kPrintfName, fnType);
}

static LLVM::GlobalOp ensureFormatString(ModuleOp module) {
  if (auto g = module.lookupSymbol<LLVM::GlobalOp>(kFormatStringName))
    return g;
  MLIRContext *ctx = module.getContext();
  OpBuilder b(module.getBodyRegion());
  auto i8 = IntegerType::get(ctx, 8);
  auto arrTy = LLVM::LLVMArrayType::get(i8, kFormatStringValue.size());
  return b.create<LLVM::GlobalOp>(
      module.getLoc(), arrTy, /*isConstant=*/true,
      LLVM::Linkage::Internal, kFormatStringName,
      StringAttr::get(ctx, kFormatStringValue),
      /*alignment=*/0);
}

struct PrintOpLowering : public OpRewritePattern<PrintOp> {
  PrintOpLowering(MLIRContext *ctx, LLVM::LLVMFuncOp printf,
                  LLVM::GlobalOp fmt)
      : OpRewritePattern<PrintOp>(ctx), printf(printf), fmt(fmt) {}

  LogicalResult matchAndRewrite(PrintOp op,
                                PatternRewriter &rewriter) const override {
    Location loc = op.getLoc();
    // AddressOfOp returns a typed pointer (`!llvm.ptr<array<N x i8>>`)
    // by default — but printf takes an opaque `!llvm.ptr`. Bitcast to
    // match. (With LLVM 17's opaque-pointer mode, the bitcast lowers
    // to a no-op in the final LLVM IR.)
    auto opaquePtr = LLVM::LLVMPointerType::get(rewriter.getContext());
    Value fmtPtr = rewriter.create<LLVM::AddressOfOp>(loc, fmt);
    fmtPtr = rewriter.create<LLVM::BitcastOp>(loc, opaquePtr, fmtPtr);
    rewriter.create<LLVM::CallOp>(loc, printf,
                                  ValueRange{fmtPtr, op.getValue()});
    rewriter.eraseOp(op);
    return success();
  }

  LLVM::LLVMFuncOp printf;
  LLVM::GlobalOp fmt;
};

struct CalcPrintToLLVMPass
    : public impl::CalcPrintToLLVMBase<CalcPrintToLLVMPass> {
  void runOnOperation() override {
    ModuleOp module = getOperation();

    // No calc.print? Nothing to do — avoid injecting unused printf
    // decl / format string.
    bool hasPrint = false;
    module.walk([&](PrintOp) {
      hasPrint = true;
      return WalkResult::interrupt();
    });
    if (!hasPrint)
      return;

    LLVM::LLVMFuncOp printf = ensurePrintfDecl(module);
    LLVM::GlobalOp fmt = ensureFormatString(module);

    RewritePatternSet patterns(&getContext());
    patterns.add<PrintOpLowering>(&getContext(), printf, fmt);
    if (failed(applyPatternsAndFoldGreedily(module, std::move(patterns))))
      signalPassFailure();
  }
};

} // namespace

std::unique_ptr<Pass> createCalcPrintToLLVMPass() {
  return std::make_unique<CalcPrintToLLVMPass>();
}

} // namespace calc
} // namespace mlir
