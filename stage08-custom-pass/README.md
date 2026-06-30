# Stage 08 — A custom pass

## What you'll learn

- The difference between **canonicalization** (always-on, single
  combined pass) and a **named pass** (opt-in, scheduled by name)
- Declarative pass definitions: `Pass<"flag", "anchor-op">` in `.td`
- The codegen that ODS does for passes (`GEN_PASS_DECL`,
  `GEN_PASS_DEF_*`, `GEN_PASS_REGISTRATION`)
- `OpRewritePattern<OpTy>` — a C++ rewrite pattern written by hand
- The `applyPatternsAndFoldGreedily` driver
- Registering and invoking your pass via `mlir-opt --calc-strength-reduce`

By the end, `calc-opt --calc-strength-reduce` will rewrite
`calc.mul %x, (calc.const 2)` into `calc.add %x, %x` — a textbook
strength reduction.

## Background

### Why a custom pass?

So far every transformation we've added (DRR canonicalization in
stage 06, folds in stage 07) ran inside the built-in `--canonicalize`
pass. That works for cheap, always-desirable rewrites like `x + 0 → x`
— things you want fired any time you reach a fixed point.

A *named pass* is for transformations that are:
- not always safe / desirable (e.g. cost-model dependent),
- expensive (so you want them only when you opt in),
- staged (e.g. lowerings — you want them in a particular pipeline
  position), or
- pedagogical (in our case).

You write one, register it under a CLI flag, and run it explicitly:

```bash
calc-opt --calc-strength-reduce input.mlir
```

### Declarative passes via ODS

You *could* write a pass entirely in C++ — inherit from
`OperationPass<func::FuncOp>`, implement `getArgument()`,
`getDescription()`, `runOnOperation()`, etc. MLIR has a more concise
way: declare the pass in a `.td` file, and let `mlir-tblgen
-gen-pass-decls` generate the plumbing.

Our `CalcPasses.td`:

```td
def CalcStrengthReduce
    : Pass<"calc-strength-reduce", "::mlir::func::FuncOp"> {
  let summary = "Replace `mul x, 2` with `add x, x`.";
  let constructor = "::mlir::calc::createCalcStrengthReducePass()";
  let dependentDialects = ["::mlir::calc::CalcDialect"];
}
```

Two important pieces:

1. **Anchor op** — the second template arg to `Pass<>`. The driver
   walks the module and invokes our pass *once per op of this type*.
   `func::FuncOp` means "once per function." A pass anchored on
   `ModuleOp` runs once total. A pass anchored on a more specific op
   only sees those ops.
2. **`dependentDialects`** — which dialects must be loaded before the
   pass runs, even if not visible in the input IR. We aren't introducing
   any new dialect here (only `calc.add`, which is already loaded), so
   listing `CalcDialect` is a safety belt rather than a hard need. It
   becomes load-bearing in stage 09/10 where we lower to *other*
   dialects.

### What `gen-pass-decls` generates

The TableGen run produces `CalcPasses.h.inc`, which gets included
three times in our C++ via macros:

| Macro | Where | What it emits |
|---|---|---|
| `GEN_PASS_DECL` | `CalcPasses.h` (once) | Forward-decl of `CalcStrengthReduceBase` |
| `GEN_PASS_DEF_<UPPER_NAME>` | `CalcPasses.cpp` (once per pass) | The base class body (must precede the pass subclass) |
| `GEN_PASS_REGISTRATION` | `CalcPasses.h` (once) | A function `registerCalcPasses()` that registers every pass with the global pass registry |

The `-name=Calc` flag we pass to `mlir-tblgen` is what makes the
registration function be `registerCalcPasses` (rather than the default
`registerPasses`).

### The rewrite pattern

A `RewritePattern` matches an IR shape and produces a replacement. The
typed variant `OpRewritePattern<MulOp>` says "I match `MulOp`":

```cpp
struct MulByTwoToAdd : public OpRewritePattern<MulOp> {
  using OpRewritePattern<MulOp>::OpRewritePattern;

  LogicalResult matchAndRewrite(MulOp op,
                                PatternRewriter &rewriter) const override {
    IntegerAttr rhsAttr;
    if (!matchPattern(op.getRhs(), m_Constant(&rhsAttr)))
      return failure();
    if (rhsAttr.getInt() != 2)
      return failure();
    rewriter.replaceOpWithNewOp<AddOp>(op, op.getType(),
                                       op.getLhs(), op.getLhs());
    return success();
  }
};
```

Mechanics:
- Return `failure()` to leave the op alone; `success()` commits.
- *Never* mutate IR outside `rewriter` — `op.erase()`,
  `rewriter.getInsertionBlock()->push_back(...)`, raw
  `builder.create<...>` calls all silently desync the worklist.
- `rewriter.replaceOpWithNewOp<NewOp>(oldOp, ctorArgs...)` is the
  idiom: build a new op, transfer the old op's uses, erase the old op.
  Atomic from the driver's POV.

### The pass driver

```cpp
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
```

`applyPatternsAndFoldGreedily` is the **greedy pattern rewrite
driver**: it builds a worklist of ops, applies patterns until a fixed
point, and also invokes any registered folds (so your stage-07 fold
methods fire here too). Most pass-based rewrites use this driver.

### Why commutativity matters here

We only check the **RHS** for the constant `2`. That feels fragile:
what about `calc.mul (calc.const 2), %x`? It works because:

1. `MulOp` has the `Commutative` trait (stage 03).
2. The greedy driver canonicalises commutative ops to put constants
   on the RHS *before* invoking our pattern.

So our one-sided pattern matches both `mul x, 2` and `mul 2, x`
sources. (`strength_reduce.mlir` tests both.)

## Glossary (new this stage)

- **Pass** — a transformation invoked by name in a pass pipeline.
  Distinct from canonicalization (which is itself one pass containing
  registered patterns and folds).
- **Anchor op** — the op type a pass runs on (e.g. `func::FuncOp`).
  The driver invokes the pass once per matching op.
- **`OperationPass<OpTy>` / `Pass<"name", "OpTy">`** — the ODS form;
  generates a base class for you.
- **`OpRewritePattern<OpTy>`** — a typed rewrite pattern; the framework
  only invokes `matchAndRewrite` on ops of that type.
- **`PatternRewriter`** — the IR-mutation API patterns must use.
  Mutating IR directly bypasses the driver's bookkeeping.
- **Greedy pattern rewrite driver** — `applyPatternsAndFoldGreedily`;
  the workhorse for pattern-based passes.
- **`registerCalcPasses()`** — the generated registration entry point;
  must be called from `main` before `MlirOptMain`.

## Tasks

Four small TODOs across three files.

### Task 1 — declare the pass in `CalcPasses.td`

In `code/CalcPasses.td`, add the `def CalcStrengthReduce : Pass<...>`
record. Copy the template from the TODO comment in the file.

### Task 2 — register the pass in `calc_opt.cpp`

Add `mlir::calc::registerCalcPasses();` after the dialect registration
in `code/calc_opt.cpp`.

### Task 3 — write the rewrite pattern body

In `code/CalcPasses.cpp`, fill in `MulByTwoToAdd::matchAndRewrite`.

### Task 4 — implement `runOnOperation`

In `code/CalcPasses.cpp`, fill in
`CalcStrengthReducePass::runOnOperation`.

## Running the tests

```bash
bazel test //stage08-custom-pass/code/...
```

The new test is `strength_reduce_test`. The five carryovers
(`round_trip_test`, `canonicalize_test`, `dce_test`, `fold_test`,
`verify_test`) should still pass — your new pass shouldn't break
unrelated behaviour.

Inspect the pass interactively:

```bash
bazel run //stage08-custom-pass/code:calc-opt -- \
    --calc-strength-reduce \
    "$PWD/stage08-custom-pass/code/strength_reduce.mlir"
```

You can also check that the pass is registered:

```bash
bazel run //stage08-custom-pass/code:calc-opt -- --help 2>&1 | \
    grep calc-strength-reduce
```

## Common mistakes

### "unknown command line argument '--calc-strength-reduce'"

You forgot Task 2 (`registerCalcPasses()` in `main`). The pass *exists*
as a C++ class but the CLI driver doesn't know about it.

### Pass runs but doesn't rewrite anything

Most likely: your `matchAndRewrite` returns `failure()` unconditionally
(the boilerplate), or the constant check uses the wrong attribute
type. Run interactively (see above) and inspect output.

If the input is `mul %x, (calc.const 2)` and nothing happens, also
check that you wired up `m_Constant` correctly — that only works
because `ConstOp` has the `ConstantLike` trait (set in stage 07).
If you accidentally regressed that, this pattern won't match either.

### Build error: `'CalcStrengthReduceBase' is not a class template`

`GEN_PASS_DEF_CALCSTRENGTHREDUCE` must be `#define`d *before*
`#include "CalcPasses.h.inc"` is pulled in via `CalcPasses.h`. But the
header is included at the top of the file, which means the
`GEN_PASS_DEF_*` macro path expects the `.inc` to be re-included.
Look at the solution: there's a deliberate second include of
`CalcPasses.h.inc` in the `.cpp` after `#define GEN_PASS_DEF_*`. Same
file, different macros gate different chunks.

### Build error: `redefinition of CalcStrengthReducePass`

You forgot to wrap your pass classes in an anonymous namespace, or you
have multiple `GEN_PASS_DEF_*` lines for the same pass.

### Driver hangs (or appears to)

If your pattern returns `success()` without actually *changing* the
IR, the driver thinks "we changed something, retry," loops forever,
hits the rewrite limit, and finally fails. Make sure every `success()`
path actually mutates IR via the rewriter.

## Try this

1. Add a `MulByPowerOfTwoToShift` pattern that rewrites
   `mul x, 2^k` into `shr` (well, `shl`, but we only have `shr`; flip
   the example to "rewrite `shr x, 1` of unsigned things into a halve
   ... actually, just add a new `calc.shl` op if you want to play").
2. Add a pass option to make the pattern threshold configurable
   (`--calc-strength-reduce='only-power-of-two=true'`). Pass options
   are another ODS field — see
   `mlir/include/mlir/Pass/PassBase.td`.
3. Confirm that `--calc-strength-reduce --canonicalize` produces the
   same final IR regardless of order (it should, by design).

## Next stage

→ Stage 09: full dialect *conversion* — lower `calc` ops to `arith`.
You'll meet `ConversionTarget`, `TypeConverter`, and the difference
between a *partial* and *full* conversion.
