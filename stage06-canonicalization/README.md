# Stage 06 — Canonicalization with DRR

## What you'll learn

- What **canonicalization** is and how the `--canonicalize` pass works
- **DRR** (Declarative Rewrite Rules) — how to write `pattern → result`
  rules directly in ODS, no C++
- How to wire DRR patterns into MLIR's canonicalizer via the per-op
  `getCanonicalizationPatterns` hook
- A new `gentbl_cc_library` flag: `-gen-rewriters`

By the end you'll have three folds running every time
`--canonicalize` is invoked: `x + 0 → x`, `x * 1 → x`, `x * 0 → 0`.

## Background

### What canonicalization is

MLIR ships with a built-in pass: `--canonicalize`. It runs every
rewrite pattern registered for every op in the input, repeatedly,
until nothing changes (a *fixpoint*). The goal is to put IR into a
**canonical form** — a small set of preferred equivalent shapes — so
later passes don't need to handle a sprawl of variations.

Examples of common canonical-form rules:
- Algebraic identities: `x + 0 → x`
- Folding pure ops on constants: `1 + 2 → 3` (next stage)
- Removing dead code: unused `Pure` ops vanish
- Normalising op orderings

You wire your dialect into this pass by giving each relevant op a list
of rewrite patterns.

### DRR: a tiny pattern DSL

For simple structural rewrites, MLIR provides **DRR** — write the
rewrite as `Pat<(source-pattern), (result-pattern)>` in a `.td` file:

```td
include "mlir/IR/PatternBase.td"
include "CalcDialect.td"

def AddZero
    : Pat<(Calc_AddOp $x, (Calc_ConstOp ConstantAttr<I32Attr, "0">)),
          (replaceWithValue $x)>;
```

Read this as:

> Match a `calc.add` whose LHS we'll call `$x` and whose RHS is a
> `calc.const` with attribute value `0`. Replace the whole match with
> the value bound to `$x`.

`mlir-tblgen -gen-rewriters` compiles each `def NAME : Pat<...>` into
a C++ `RewritePattern` subclass named `NAME`.

#### DRR cheat sheet

**Source side** (the thing we match):

| Form | Meaning |
|---|---|
| `(Op $a, $b)` | match `Op` with two operands, bind them to `$a`/`$b` |
| `(Op:$x $a, $b)` | also bind the matched value/op as `$x` |
| `$a:value` (suffix) | bind only the SSA value, not the defining op |
| `ConstantAttr<I32Attr, "0">` | match an `I32Attr` with the constant value `0` |
| `(Op (OtherOp $y))` | nested matching — the operand must itself be `OtherOp` |

**Result side** (what we replace with):

| Form | Meaning |
|---|---|
| `(replaceWithValue $x)` | replace the matched op with an existing SSA value `$x` |
| `(NewOp $a, $b)` | build a new op |
| `(NewOp $a, (otherNewOp ...))` | nested op construction |

We use the simplest forms (`replaceWithValue`) in this stage. The next
stage covers `fold()` methods, which compute constant results in C++.

### Wiring patterns into the canonicalizer

Three pieces, all required:

1. **`let hasCanonicalizer = 1;`** in each op's ODS. This generates
   the declaration:

   ```cpp
   static void Op::getCanonicalizationPatterns(
       RewritePatternSet &results, MLIRContext *context);
   ```

2. **Implement the body** in your `.cpp`:

   ```cpp
   void AddOp::getCanonicalizationPatterns(
       RewritePatternSet &results, MLIRContext *context) {
     results.add<AddZero>(context);
   }
   ```

   The pattern *names* are the `def NAME : Pat<...>` from your `.td`.

3. **Include the generated header** somewhere visible to the
   implementation:

   ```cpp
   namespace {
   #include "CalcCanonicalize.inc"
   } // namespace
   ```

   The anonymous namespace prevents linker collisions if multiple
   translation units include the same generated patterns.

### The Bazel side: `-gen-rewriters`

A third `gentbl_cc_library` (alongside dialect-decls and op-decls):

```python
gentbl_cc_library(
    name = "CalcCanonicalizeIncGen",
    strip_include_prefix = ".",
    tbl_outs = [
        (["-gen-rewriters"], "CalcCanonicalize.inc"),
    ],
    tblgen = "@llvm-project//mlir:mlir-tblgen",
    td_file = "CalcPatterns.td",
    deps = [":CalcDialectTdFiles"],
)
```

And of course the new `cc_library` dep on `:CalcCanonicalizeIncGen`.

### A subtlety: the `MulZero` pattern

```td
def MulZero
    : Pat<(Calc_MulOp $x,
                      (Calc_ConstOp:$zero ConstantAttr<I32Attr, "0">)),
          (replaceWithValue $zero)>;
```

For `x * 0`, the correct replacement is the *zero constant*, not
`$x`. So we **bind the constant op** with `:$zero` and replace with
that. (Replacing with `$x` would change the result type if `$x` is
ever a different type — which it can't be in our i32-only world, but
still.)

## Glossary (new this stage)

- **Canonicalization** — the standard MLIR transformation that
  repeatedly applies registered rewrite patterns until IR stabilises.
  Run via `--canonicalize`.
- **Canonical form** — the preferred shape of an IR after
  canonicalization. The point is determinism: equivalent inputs
  produce identical outputs.
- **DRR** — Declarative Rewrite Rules. The `.td`-level DSL for
  source→result patterns.
- **Pattern** — a single rewrite rule. Subclass of
  `RewritePattern` in C++ (or `Pat<...>` in DRR).
- **`RewritePatternSet`** — a container of patterns; the canonicalizer
  consumes one per op.
- **`getCanonicalizationPatterns`** — the per-op hook the canonicalizer
  calls to collect patterns.
- **`-gen-rewriters`** — `mlir-tblgen` mode that compiles DRR
  `Pat<...>` records into C++ `RewritePattern` classes.
- **Fixpoint** — the state where repeated application of patterns
  changes nothing; the canonicalizer stops here.

## Tasks

Three files involved: `CalcPatterns.td` (new patterns), `CalcDialect.td`
(flip a switch), `CalcDialect.cpp` (wire patterns in).

### Task 1 — write the three patterns

In `code/CalcPatterns.td`, define `AddZero`, `MulOne`, `MulZero`
using the shapes shown in the TODO comment. Names must match exactly.

### Task 2 — enable canonicalization on AddOp and MulOp

In `code/CalcDialect.td`, add `let hasCanonicalizer = 1;` to BOTH
`Calc_AddOp` and `Calc_MulOp`. Without this, the generated op classes
don't even have a `getCanonicalizationPatterns` method to override.

### Task 3 — implement the hooks

In `code/CalcDialect.cpp`, implement:

```cpp
void AddOp::getCanonicalizationPatterns(RewritePatternSet &results,
                                        MLIRContext *context) {
  results.add<AddZero>(context);
}

void MulOp::getCanonicalizationPatterns(RewritePatternSet &results,
                                        MLIRContext *context) {
  results.add<MulOne, MulZero>(context);
}
```

## Running the tests

```bash
bazel test //stage06-canonicalization/code/...
```

Four tests:

| Test | Checks |
|---|---|
| `canonicalize_test` | the three folds happen under `--canonicalize` |
| `round_trip_test` | parse/print still works |
| `dce_test` | side-effects work (regression) |
| `verify_test` | `calc.shr` verifier still works (regression) |

Inspect canonicalizer behaviour interactively:

```bash
bazel run //stage06-canonicalization/code:calc-opt -- \
    --canonicalize \
    "$PWD/stage06-canonicalization/code/canonicalize.mlir"
```

## Common mistakes

### `error: Variable not defined: 'Calc_AddOp'` (in DRR compilation)

`CalcPatterns.td` doesn't `include "CalcDialect.td"`. The patterns
reference op records by name, so they need access to the definitions.
Already handled in boilerplate — but watch out if you fork.

### Test fails: pattern doesn't fire

Walk through the source pattern carefully:
- Order matters — `Pat<(Calc_AddOp $x, (Calc_ConstOp ...))>` only
  matches a constant on the RHS. `(Calc_ConstOp ...), $x)` is a
  different pattern.
- `Commutative` does NOT automatically reorder operands for custom
  ops. If you want both LHS-constant and RHS-constant matches, write
  two patterns. (We rely only on the natural order in `canonicalize.mlir`
  this stage.)
- `ConstantAttr<I32Attr, "0">` matches only an `I32Attr` equal to 0.
  If your constant is `i64`, it won't match.

### Build fails: `member access into incomplete type 'RewritePatternSet'`

You're missing `#include "mlir/IR/PatternMatch.h"` in `CalcDialect.h`.
(Boilerplate has it now.)

### Build fails: `undefined symbol AddZero` at link time

The `-gen-rewriters` `gentbl_cc_library` isn't in your `cc_library`
deps. Or you forgot to include `CalcCanonicalize.inc` in the
anonymous namespace block of `CalcDialect.cpp`.

### `error: shift amount must be in...` from a shr op

That's stage 05's verifier still working. Not related to
canonicalization.

## Why DRR, not C++ patterns?

For shape-only rewrites (match shape, replace shape), DRR is more
concise and harder to get wrong than the C++ equivalent. Compare —
the same `AddZero` rule as a C++ `RewritePattern`:

```cpp
struct AddZeroPattern : public OpRewritePattern<AddOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(AddOp op,
                                PatternRewriter &rewriter) const override {
    auto rhs = op.getRhs().getDefiningOp<ConstOp>();
    if (!rhs || rhs.getValue() != 0) return failure();
    rewriter.replaceOp(op, op.getLhs());
    return success();
  }
};
```

15 lines vs 3. But C++ is needed when the rewrite involves
computation (e.g., `const a + const b → const (a+b)`) — that's stage
07.

## Try this

Add a fourth pattern: `x - 0 → x`. (You'd need a `calc.sub` op first
— we don't have one. So instead, try `x + x → x * 2`. This requires
your result pattern to *build a new op*:

```td
def AddSelfToMul2
    : Pat<(Calc_AddOp $x, $x),
          (Calc_MulOp $x, (Calc_ConstOp ConstantAttr<I32Attr, "2">))>;
```

Wire it into `AddOp::getCanonicalizationPatterns` and add a test
case. Note this might NOT actually fire if the canonicalizer prefers
other rewrites — try it and see what happens.

## Next stage

→ Stage 07: `fold()` methods — compute constant results when DRR's
shape-matching isn't enough.
