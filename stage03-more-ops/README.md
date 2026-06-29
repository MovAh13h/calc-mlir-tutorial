# Stage 03 — More ops: `calc.add` and `calc.mul`

## What you'll learn

- How to declare an op that takes **operands** (other SSA values), not
  just attributes
- More traits: **`Commutative`** and **`SameOperandsAndResultType`**
- How traits double as **verifier rules**
- How `SameOperandsAndResultType` lets the assembly format print just
  one type for all matching operands/results
- Composing ops in real IR (e.g. computing `(x+1) * (x+2)`)

By the end you'll have a three-op dialect that can express integer
expressions over i32.

## Background

### Operands, finally

`calc.const` had only an *attribute* (`I32Attr:$value`). `calc.add` has
two **operands** — actual SSA values produced by earlier ops:

```td
let arguments = (ins I32:$lhs, I32:$rhs);
let results = (outs I32:$result);
```

Note: operands and attributes both live in `(ins ...)`. ODS
distinguishes them by type: types like `I32`, `AnyType`, `Tensor<...>`
are operand specs; types ending in `Attr` (like `I32Attr`, `StrAttr`)
are attribute specs.

### Two new traits

#### `Commutative`

Marker that operand order doesn't affect semantics. The canonicalizer
uses this to put operands in a deterministic order (typically: constant
on the right), which makes other rewrite patterns simpler to write.

For example, after canonicalization:

```mlir
%c = calc.const 5 : i32
%s = calc.add %c, %x : i32       // input

// becomes:
%s = calc.add %x, %c : i32       // constant moved to RHS
```

This is purely cosmetic *until* you write a pattern like "if RHS is a
constant zero, replace with LHS." The pattern only has to look at one
side, not both, because the canonicalizer guarantees the constant is
on the RHS.

(We'll write exactly such patterns in stage 06.)

#### `SameOperandsAndResultType`

This is a **verifier trait**: the op's `verify()` method (auto-generated
from the trait) checks that `lhs`, `rhs`, and `result` all have the
same type. If they don't, `mlir-opt` rejects the IR with a clear error.

It also has a parser/printer side-effect: when you write

```td
let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
```

…you only specify *one* type (the result's). The trait propagates that
type to `$lhs` and `$rhs` automatically. Without the trait, you'd have
to print all three:

```td
let assemblyFormat = "$lhs `,` $rhs attr-dict `:` " #
                     "functional-type(operands, results)";
```

…which would print as `calc.add %a, %b : (i32, i32) -> i32`. Ugly.

### The Bazel side: one extra dep

`SameOperandsAndResultType` lives in
`mlir/Interfaces/InferTypeOpInterface.td`, which is a *different* .td
file from the one we used last stage. We add it to both:

```python
td_library(
    ...
    deps = [
        "@llvm-project//mlir:InferTypeOpInterfaceTdFiles",  # ← new
        "@llvm-project//mlir:OpBaseTdFiles",
        "@llvm-project//mlir:SideEffectInterfacesTdFiles",
    ],
)

cc_library(
    ...
    deps = [
        ...
        "@llvm-project//mlir:InferTypeOpInterface",          # ← new
        ...
    ],
)
```

And the matching C++ include in `CalcDialect.h`:

```cpp
#include "mlir/Interfaces/InferTypeOpInterface.h"
```

You'll find this pattern again and again: every interface/trait you add
needs both a `.td` include (for ODS) and a C++ include (for the
generated code that uses it).

## Glossary (new this stage)

- **`Commutative` trait** — operand order is semantically irrelevant.
  Canonicalizer uses this to normalize operand order.
- **`SameOperandsAndResultType` trait** — verifier check that all
  operands and results share a single type; also reduces the number of
  types you have to print in the assembly format.
- **Verifier trait** — a trait that contributes a check to the op's
  `verify()` method.
- **Type inference trait** — a trait that, given some types, derives
  the rest (e.g. `SameOperandsAndResultType` infers operand types from
  the result type).

## Tasks

One file to edit: `code/CalcDialect.td`. `calc.const` is already there
from stage 02. You add two more ops.

### Task 1 — define `calc.add`

```td
def Calc_AddOp : Calc_Op<"add",
    [Pure, Commutative, SameOperandsAndResultType]> {
  let summary = "...";
  let arguments = (ins I32:$lhs, I32:$rhs);
  let results = (outs I32:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}
```

### Task 2 — define `calc.mul`

Same structure as `calc.add`, just change the mnemonic and the
summary. (Integer multiplication is also commutative.)

## Running the tests

```bash
bazel test //stage03-more-ops/code:round_trip_test
```

Or run `calc-opt` on the test file directly to see the round-trip:

```bash
bazel run //stage03-more-ops/code:calc-opt -- \
    "$PWD/stage03-more-ops/code/round_trip.mlir"
```

## Common mistakes

### `Variable not defined: 'SameOperandsAndResultType'`

You forgot the `.td` include:

```td
include "mlir/Interfaces/InferTypeOpInterface.td"
```

(The stage's boilerplate already has it — but worth knowing why.)

### `no member named 'InferTypeOpInterface' in namespace 'mlir'`

You're missing the C++ side. Add both:

- `#include "mlir/Interfaces/InferTypeOpInterface.h"` to `CalcDialect.h`
- `"@llvm-project//mlir:InferTypeOpInterface"` to the `cc_library` deps

(Boilerplate has both — but watch out if you fork.)

### Test fails: `op operand and result types must match`

You forgot `SameOperandsAndResultType`. The build succeeds, but writing
`calc.add %a, %b : i32` where one operand isn't i32 will fail
verification. (Hard to hit if you're only working with `i32` values —
but the trait is what guarantees it.)

### Test fails with `expected ':'`

Your assembly format is wrong. The standard binary-op format is:

```td
"$lhs `,` $rhs attr-dict `:` type($result)"
```

Mind the backticks around literals and the order: `attr-dict` before
the type so the type isn't accidentally consumed as part of the dict.

## Try this

Once your build is green, write your own `.mlir` file with bigger
expressions and round-trip it:

```bash
cat > /tmp/expr.mlir <<'EOF'
func.func @triangle(%n: i32) -> i32 {
  %c1 = calc.const 1 : i32
  %a = calc.add %n, %c1 : i32      // n+1
  %p = calc.mul %n, %a : i32       // n*(n+1)
  %c2 = calc.const 2 : i32
  // FIXME: there's no calc.div yet, so we can't compute n*(n+1)/2
  return %p : i32
}
EOF
bazel run //stage03-more-ops/code:calc-opt -- /tmp/expr.mlir
```

Notice that all the values are unnamed (`%0`, `%1`, ...) when printed —
MLIR doesn't preserve SSA names. That's why our `// CHECK:` lines use
`%[[VAR:.*]]` captures.

## Next stage

→ Stage 04: `calc.print`, our first side-effecting op (no `Pure`
trait; introduces `MemoryEffects`).
