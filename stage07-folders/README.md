# Stage 07 — Fold methods

## What you'll learn

- The difference between **patterns** (rewrite IR shape) and **folds**
  (compute constant results)
- How `let hasFolder = 1;` and `OpFoldResult Op::fold(FoldAdaptor)`
  fit together
- Why `ConstantLike` and `hasConstantMaterializer` are both needed
  before folds can actually run end-to-end
- `matchPattern` + `m_Constant` for "is this operand a constant?"

By the end you'll have `1 + 2 → 3`, `6 * 7 → 42`, and full chained
folding like `(1+2) * (3+4) → 21` happening under `--canonicalize`.

## Background

### Fold vs. pattern — when to use which

| | Fold | Pattern (DRR or C++) |
|---|---|---|
| Question it answers | "given this op's operands, can I produce a constant result?" | "does this IR shape match, and if so what's the replacement?" |
| Output | an `Attribute` (new constant) or a `Value` (existing SSA value) | an arbitrary new op (or set of ops) |
| Example | `1 + 2 → 3` | `x + 0 → x` |
| Implementation | C++ method `Op::fold(FoldAdaptor)` | DRR `Pat<...>` or C++ `RewritePattern` |

Both run inside `--canonicalize`. Folds run first per-op; if a fold
succeeds, the result replaces the op. Patterns then run on whatever's
left.

### `OpFoldResult` and the FoldAdaptor

```cpp
OpFoldResult ConstOp::fold(FoldAdaptor adaptor);
```

`OpFoldResult` is a union of `Attribute` and `Value` (plus null):

| Return value | Effect |
|---|---|
| `IntegerAttr` (or any `Attribute`) | replace result with a fresh constant carrying that attribute (via `materializeConstant`) |
| `Value` | replace result with that existing SSA value |
| `{}` (null) | fold failed; no change |

`FoldAdaptor` is a class auto-generated alongside the op. Its
operand accessors (e.g. `adaptor.getLhs()`) return the operand's
**folded constant attribute** if that operand is known constant, or
null otherwise. So a typical binary fold looks like:

```cpp
OpFoldResult AddOp::fold(FoldAdaptor adaptor) {
  IntegerAttr lhs, rhs;
  if (!matchPattern(getLhs(), m_Constant(&lhs)) ||
      !matchPattern(getRhs(), m_Constant(&rhs)))
    return {};
  return IntegerAttr::get(getType(), lhs.getInt() + rhs.getInt());
}
```

(We use `matchPattern(value, m_Constant(&attr))` rather than
`adaptor.getLhs()` because the matcher is more robust and clearer
about what it does. Either works.)

### Why our `calc.const` fold returns the value attribute

```cpp
OpFoldResult ConstOp::fold(FoldAdaptor adaptor) {
  return adaptor.getValueAttr();
}
```

This looks pointless — we're folding a constant to itself — but it's
the **bridge** that makes the fold framework see our constants. With
this fold + the `ConstantLike` trait:

```td
def Calc_ConstOp : Calc_Op<"const", [Pure, ConstantLike]> { ... }
```

…downstream ops calling `matchPattern(op.getLhs(), m_Constant(&attr))`
get back our `IntegerAttr`. Without it, `m_Constant` doesn't find our
constants and nothing folds.

> Subtle: `adaptor.getValueAttr()` is `IntegerAttr`. The op's
> auto-generated `getValue()` returns `uint32_t` (since we declared
> the value as `I32Attr`). Returning `getValue()` won't compile —
> `OpFoldResult` only accepts `Attribute` or `Value`.

### The `materializeConstant` hook

When `AddOp::fold` returns an `IntegerAttr`, the canonicalizer needs
to *replace* the `calc.add` with a new constant op carrying that
attribute. But the canonicalizer doesn't know which dialect's
constant op to create. It asks the dialect:

```cpp
Operation *CalcDialect::materializeConstant(OpBuilder &builder,
                                            Attribute value,
                                            Type type, Location loc) {
  if (auto intAttr = dyn_cast<IntegerAttr>(value))
    return builder.create<ConstOp>(loc, type, intAttr);
  return nullptr;
}
```

ODS generates the declaration from `let hasConstantMaterializer = 1;`
on the dialect.

Without this, your `AddOp::fold` returns an `IntegerAttr` and the
canonicalizer silently drops it — fold appears to do nothing.

### The full chain

```
canonicalize starts on AddOp
   │
   ├─ canonicalize first folds operands
   │    └─ ConstOp::fold returns IntegerAttr (visible to m_Constant)
   │
   ├─ AddOp::fold called
   │    ├─ matchPattern(getLhs(), m_Constant(&lhs))  ← needs ConstantLike
   │    ├─ matchPattern(getRhs(), m_Constant(&rhs))
   │    └─ returns IntegerAttr(lhs + rhs)
   │
   └─ canonicalizer asks dialect to materialize the attribute
        └─ CalcDialect::materializeConstant returns new calc.const op
            └─ AddOp is replaced by the new const op
```

All four pieces — `ConstantLike` trait, `hasFolder` on each op, fold
methods, `materializeConstant` — must be in place for end-to-end
folding to work.

## Glossary (new this stage)

- **Fold** — an op-level method that computes a constant result when
  possible. Faster path than a pattern; runs first.
- **`OpFoldResult`** — return type of `fold()`. A union of
  `Attribute`, `Value`, and null.
- **`FoldAdaptor`** — op-specific adaptor giving typed access to
  constant operand attributes during fold.
- **`hasFolder = 1`** — ODS flag to generate the `fold()` method
  declaration.
- **`ConstantLike` trait** — marks an op as MLIR's notion of a
  constant. Enables `m_Constant` matching.
- **`hasConstantMaterializer = 1`** — dialect-level ODS flag that
  declares `materializeConstant` on the dialect class.
- **`materializeConstant`** — dialect hook the canonicalizer calls to
  build an op from a folded constant attribute.
- **`matchPattern(value, m_Constant(&attr))`** — idiomatic check for
  "is this operand a constant; if so bind its attribute to `attr`."

## Tasks

Two files: `CalcDialect.td` (add three ODS lines) and
`CalcDialect.cpp` (implement four C++ methods).

### Task 1 — dialect-level materializer flag

In `code/CalcDialect.td`, inside `def Calc_Dialect`, add:

```td
let hasConstantMaterializer = 1;
```

### Task 2 — `ConstantLike` + `hasFolder` on ConstOp

Add `ConstantLike` to the trait list, and add `let hasFolder = 1;` to
the body.

### Task 3 — `hasFolder` on AddOp and MulOp

Add `let hasFolder = 1;` to both.

### Task 4 — implement `materializeConstant`

In `code/CalcDialect.cpp`, write the method body. See the TODO
comment for the exact shape.

### Task 5 — implement three fold methods

`ConstOp::fold`, `AddOp::fold`, `MulOp::fold`. See the TODO comment
for shapes.

## Running the tests

```bash
bazel test //stage07-folders/code/...
```

The interesting test is `fold_test` — `canonicalize_test`, `dce_test`,
`round_trip_test`, `verify_test` all carry over from prior stages.

Inspect interactively:

```bash
bazel run //stage07-folders/code:calc-opt -- \
    --canonicalize \
    "$PWD/stage07-folders/code/fold.mlir"
```

You should see `calc.const 21` for the chained case, no `calc.add`
or `calc.mul`.

## Common mistakes

### Test fails: fold didn't fire

Common cause: you forgot the `ConstantLike` trait on `ConstOp`,
or you forgot `hasConstantMaterializer = 1` on the dialect, or you
forgot the `materializeConstant` implementation. All three are
required.

Quick diagnostic — run the binary without --canonicalize and see if
it parses. If yes, the build is fine and one of the four pieces is
missing.

### `OpFoldResult` doesn't accept `uint32_t`

You wrote `return adaptor.getValue();` in `ConstOp::fold`. Our
`getValue()` returns `uint32_t` (the integer literal) because the
attribute is `I32Attr`. `OpFoldResult` wants `Attribute` or `Value`.
Use `adaptor.getValueAttr()` (returns `IntegerAttr`).

### Build error: `m_Constant` not declared

Missing `#include "mlir/IR/Matchers.h"`. The boilerplate has it.

### `error: function 'fold' must be defined`

You set `let hasFolder = 1;` in ODS but didn't implement `fold()` in
C++. Add the method.

### Linker error: `materializeConstant` not defined

You set `let hasConstantMaterializer = 1;` but didn't implement
`materializeConstant`. Add it.

### Folds work for `add` but not for `mul` (or vice versa)

You forgot `let hasFolder = 1;` on one of them, or forgot the matching
implementation. They're independent — each op needs both pieces.

## Try this

Add a fold for `calc.shr`:

```cpp
OpFoldResult ShrOp::fold(FoldAdaptor adaptor) {
  IntegerAttr value, amount;
  if (!matchPattern(getValue(), m_Constant(&value)) ||
      !matchPattern(getAmount(), m_Constant(&amount)))
    return {};
  return IntegerAttr::get(getType(),
                          value.getInt() >> (amount.getInt() & 31));
}
```

Add `let hasFolder = 1;` to `Calc_ShrOp` and write a `.mlir` test for
`calc.shr (calc.const 64) (calc.const 2) → calc.const 16`.

## Next stage

→ Stage 08: a custom pass — your own transformation outside of
canonicalization (`calc-strength-reduce`: replace `mul x, 2` with
`add x, x`).
