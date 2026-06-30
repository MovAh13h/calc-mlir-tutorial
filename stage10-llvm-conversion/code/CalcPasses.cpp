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
// Stage 10 — calc.print → llvm.call @printf.   TODO (Tasks 2–5).
//
// Target IR:
//
//   llvm.mlir.global internal constant @calc_print_fmt("%d\n\00")
//   llvm.func @printf(!llvm.ptr, ...) -> i32
//
//   func.func @user(...) {
//     ...
//     %f0 = llvm.mlir.addressof @calc_print_fmt
//             : !llvm.ptr<array<4 x i8>>          // typed pointer
//     %f  = llvm.bitcast %f0 to !llvm.ptr         // opaque ptr for printf
//     llvm.call @printf(%f, %v) : (!llvm.ptr, i32) -> i32
//   }
//
// In LLVM 17, AddressOfOp returns a *typed* pointer to the global's
// type. printf takes an *opaque* pointer (`!llvm.ptr`). We bridge
// with a bitcast (which becomes a no-op in the final LLVM IR once
// opaque pointers are the universal mode).
// =============================================================================
namespace {

static constexpr llvm::StringRef kFormatStringName = "calc_print_fmt";
static constexpr llvm::StringRef kPrintfName = "printf";
// "%d\n" + terminator. Length includes the trailing nul.
static constexpr llvm::StringRef kFormatStringValue("%d\n\0", 4);

// TODO (Task 2) — implement ensurePrintfDecl.
//
// Look up `@printf` in `module`; if missing, create an LLVMFuncOp
// declaration with signature `i32 (ptr, ...)` (variadic). Return the
// op.
//
// Tips:
//   - `module.lookupSymbol<LLVM::LLVMFuncOp>(name)` returns nullptr
//     if not found.
//   - Use `OpBuilder b(module.getBodyRegion())` to insert at the top
//     of the module body.
//   - Function type: `LLVM::LLVMFunctionType::get(returnTy, argTys,
//                                                /*isVarArg=*/true)`.
//   - Opaque pointer type: `LLVM::LLVMPointerType::get(ctx)`.
static LLVM::LLVMFuncOp ensurePrintfDecl(ModuleOp module) {
  // TODO: implement.
  return {};
}

// TODO (Task 3) — implement ensureFormatString.
//
// Look up `@calc_print_fmt`; if missing, create an LLVM::GlobalOp
// with:
//   - type:      array<4 x i8>
//   - constant:  true
//   - linkage:   LLVM::Linkage::Internal
//   - name:      "calc_print_fmt"
//   - initial value: StringAttr "%d\n\0" (kFormatStringValue)
static LLVM::GlobalOp ensureFormatString(ModuleOp module) {
  // TODO: implement.
  return {};
}

// TODO (Task 4) — implement the print → llvm.call lowering.
//
// The pattern carries pointers to `printf` and the format global,
// which the pass passes in at construction time.
//
//   1. AddressOf the global  →  typed pointer
//   2. Bitcast to opaque `!llvm.ptr`
//   3. llvm.call @printf(fmtPtr, op.getValue())
//   4. erase the calc.print
struct PrintOpLowering : public OpRewritePattern<PrintOp> {
  PrintOpLowering(MLIRContext *ctx, LLVM::LLVMFuncOp printf,
                  LLVM::GlobalOp fmt)
      : OpRewritePattern<PrintOp>(ctx), printf(printf), fmt(fmt) {}

  LogicalResult matchAndRewrite(PrintOp op,
                                PatternRewriter &rewriter) const override {
    // TODO: implement.
    return failure();
  }

  LLVM::LLVMFuncOp printf;
  LLVM::GlobalOp fmt;
};

// TODO (Task 5) — implement the pass.
//
// Walk the module to see if any calc.print exists; if not, early-out.
// Otherwise ensure the decl + global, build a RewritePatternSet with
// PrintOpLowering, and call applyPatternsAndFoldGreedily.
struct CalcPrintToLLVMPass
    : public impl::CalcPrintToLLVMBase<CalcPrintToLLVMPass> {
  void runOnOperation() override {
    // TODO: implement.
  }
};

} // namespace

std::unique_ptr<Pass> createCalcPrintToLLVMPass() {
  return std::make_unique<CalcPrintToLLVMPass>();
}

} // namespace calc
} // namespace mlir
