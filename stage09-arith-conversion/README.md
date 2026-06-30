# Stage 09 — Conversion to the `arith` dialect

## What you'll learn

- The difference between a **rewrite pattern** (stage 06–08) and a
  **conversion pattern** — and why you need both
- `ConversionTarget`: declaring which ops are legal vs illegal in the
  output IR
- `OpConversionPattern<OpTy>` + `OpAdaptor` — the conversion analogue
  of `OpRewritePattern`
- **Partial vs full** dialect conversion
- Lowering `calc.const`, `calc.add`, `calc.mul`, `calc.shr` to their
  `arith` equivalents while leaving `calc.print` in place

By the end, `calc-opt --calc-to-arith` will rewrite all calc arithmetic
into arith ops; calc.print survives, awaiting stage 10.

## Background

### Why a different pattern type?

Stage 08's `OpRewritePattern<MulOp>` rewrote a calc op into another
calc op. Both ops had the same operand types (i32) and the IR around
them never changed.

A *dialect conversion* is different: you're lowering between dialects,
sometimes with **type changes**. Consider a future lowering where
`calc.fixed<8, 8>` (a hypothetical fixed-point type) becomes
`tuple<i16>` in some other dialect. While the conversion is in
progress, the IR contains a mix of the old type and the new — old ops
in calc-land, new ops in target-land — and the operands of an
in-flight rewrite may have already been remapped to the new type.

To deal with that, conversion uses:

- A **`TypeConverter`** that maps source types to target types.
- An **`OpAdaptor`** passed to your pattern. `adaptor.getLhs()`
  returns the **remapped** operand value, not the original one. If a
  pattern asked `op.getLhs()` directly it would see the stale,
  un-remapped operand.

Even though our `calc → arith` lowering is type-preserving (all i32),
we still use this framework — it's idiomatic and sets up stage 10.

### `ConversionTarget`

A `ConversionTarget` is the declaration of "what counts as a legal
output." It exposes:

```cpp
target.addLegalDialect<arith::ArithDialect, func::FuncDialect>();
target.addIllegalDialect<CalcDialect>();
target.addLegalOp<PrintOp>();   // keep this one calc op alive
```

The driver consults the target to decide what to rewrite. Anything
already legal is left alone. Anything illegal must be rewritten by a
pattern; otherwise the conversion fails (or, in partial mode, the
illegal op survives and we error out).

### Partial vs full conversion

| | Partial | Full |
|---|---|---|
| Driver | `applyPartialConversion` | `applyFullConversion` |
| Output requirement | every *illegal* op must be rewritten; legal ops may stay | every op in the output must be in the legal set, even those that started legal |
| Used when | mid-pipeline lowering — you only know how to convert some ops | the final lowering step before codegen |

We want **partial** here: we're lowering arithmetic but deliberately
leaving `calc.print`. In stage 10 we'll do a full conversion to LLVM
(everything must be LLVM at the end).

### One pattern per op

```cpp
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
```

Compare to the stage-08 pattern:
- Inherits `OpConversionPattern<AddOp>` (not `OpRewritePattern`).
- `matchAndRewrite` takes an extra `OpAdaptor adaptor`.
- The rewriter is `ConversionPatternRewriter` (a `PatternRewriter`
  subclass with extra conversion-aware methods).

For our type-preserving case, `adaptor.getLhs()` returns the same
`Value` as `op.getLhs()`. We use `adaptor` anyway to stay in the
conversion idiom.

### Why `calc.const` uses `op.getValueAttr()` directly

```cpp
rewriter.replaceOpWithNewOp<arith::ConstantOp>(op, op.getType(),
                                               op.getValueAttr());
```

`arith.constant` takes a typed attribute. `op.getValueAttr()` returns
the `IntegerAttr` from the calc.const, and arith.constant accepts it
directly. (This is the same `getValueAttr()` we used in stage-07's
ConstOp::fold.)

### Why the partial conversion sometimes "folds for you"

If you run `--calc-to-arith` on a function whose arithmetic operates
on constants, you'll often see the result already collapsed:

```mlir
func.func @x() -> i32 {
  %a = calc.const 3 : i32
  %b = calc.const 4 : i32
  %r = calc.add %a, %b : i32
  return %r : i32
}
```

becomes

```mlir
func.func @x() -> i32 {
  %0 = arith.constant 7 : i32    // not 3 + 4 separately!
  return %0 : i32
}
```

The conversion driver runs each new op's `fold()` immediately after
creation, and `arith.addi`'s built-in fold collapses two constants.
This is why our test cases use function arguments — to keep ops
visible.

## Glossary (new this stage)

- **Dialect conversion** — the framework for lowering between dialects
  in a coordinated, type-aware way.
- **`ConversionTarget`** — declares legality of ops/dialects in the
  output.
- **Legal / illegal** — properties an op has *relative to a
  ConversionTarget*. The driver tries to rewrite illegal ops; legal
  ones are left alone (in partial mode).
- **Partial conversion** — succeeds as long as no illegal op survives;
  legal ops may remain.
- **Full conversion** — every op must be in the legal set at the end.
- **`OpConversionPattern<OpTy>`** — pattern subclass for conversion;
  receives an `OpAdaptor`.
- **`OpAdaptor`** — op-specific accessor giving you the *remapped*
  operand values during conversion.
- **`ConversionPatternRewriter`** — `PatternRewriter` subclass for
  conversion; has type-aware helpers.
- **`TypeConverter`** — maps source types to target types. We don't
  need one here (all i32 → i32), but more interesting lowerings do.

## Tasks

Four TODOs, all in `code/CalcPasses.td` and `code/CalcPasses.cpp`.

### Task 1 — declare the pass

In `code/CalcPasses.td`, add `def CalcToArith : Pass<...>`. Template
in the file's TODO comment.

### Task 2 — four conversion patterns

In `code/CalcPasses.cpp`, write `ConstOpLowering`, `AddOpLowering`,
`MulOpLowering`, `ShrOpLowering`. Templates in the TODO comment.

### Task 3 — the pass class

`struct CalcToArithPass : public impl::CalcToArithBase<...>` with
`runOnOperation` that sets up the target, adds patterns, and runs
`applyPartialConversion`.

### Task 4 — factory function

`createCalcToArithPass()` returning a `std::unique_ptr<Pass>`.

The header `CalcPasses.h` already declares all four pieces; you're
filling in the bodies.

## Running the tests

```bash
bazel test //stage09-arith-conversion/code/...
```

The new test is `calc_to_arith_test`. All carryovers
(`round_trip`, `canonicalize`, `dce`, `fold`, `verify`,
`strength_reduce`) should still pass.

Interactive:

```bash
bazel run //stage09-arith-conversion/code:calc-opt -- \
    --calc-to-arith \
    "$PWD/stage09-arith-conversion/code/calc_to_arith.mlir"
```

## Common mistakes

### "failed to legalize operation 'calc.print'"

You marked `CalcDialect` illegal but forgot `addLegalOp<PrintOp>()`,
or you added it BEFORE `addIllegalDialect`. Order matters — the later
call wins.

### "failed to legalize operation 'calc.shr'"

You forgot to register `ShrOpLowering` in `patterns.add<...>()`.

### Crash: "dialect 'arith' not loaded"

Missing `dependentDialects = ["::mlir::arith::ArithDialect"]` on the
pass def in `CalcPasses.td`. Even though the input IR has no arith
ops, the pass *creates* them, so the dialect must be loaded.

### Test fails: arith.addi missing because constants were folded

Your code is probably correct — the conversion driver runs folds and
arith.addi of two constants becomes one constant. Use function
arguments in your test inputs to stop the fold from collapsing the
op away. (Our tests already do this.)

### "OpAdaptor not found" / compile errors

You wrote `OpConversionPattern<MyOp>::OpAdaptor` in the wrong place,
or your `matchAndRewrite` signature doesn't take the adaptor. The
exact signature is:

```cpp
LogicalResult matchAndRewrite(MyOp op, OpAdaptor adaptor,
                              ConversionPatternRewriter &rewriter)
    const override;
```

`OpAdaptor` is a typedef in `OpConversionPattern<MyOp>`, so writing
it bare in the parameter list is correct.

## Try this

1. Make the conversion **full** by also lowering `calc.print` here.
   What happens to the output? (Spoiler: it fails — no pattern for
   `func.return` or `func.func`. Full conversion needs every op
   covered.)
2. Add an alternative path: write `ShrOpLowering` as `arith.shrsi`
   (signed shift right) instead of `arith.shrui` and see how the test
   behavior changes. (Hint: it doesn't, because we don't currently
   exercise negative values.)
3. Swap `applyPartialConversion` for `applyFullConversion` and watch
   it complain.

## Next stage

→ Stage 10: full conversion to the LLVM dialect, including
`calc.print` → `llvm.call @printf`. You'll meet
`LLVMConversionTarget`, the printf prelude, and the difference
between the LLVM dialect and actual LLVM IR.
