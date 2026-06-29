# Stage 02 — Your first op: `calc.const`

## What you'll learn

- How to declare an **operation** in ODS
- What **arguments**, **results**, and **attributes** are at the IR level
- What **traits** are (we'll use `Pure`)
- The **assembly format** mini-DSL for op syntax
- How to register ops in your dialect's `initialize()`
- How `mlir-tblgen -gen-op-{decls,defs}` plugs into Bazel

By the end you'll have a `calc.const` op that round-trips through
`calc-opt`:

```mlir
%x = calc.const 42 : i32
```

## Background

### Anatomy of an op declaration (ODS)

```td
def Calc_ConstOp : Calc_Op<"const", [Pure]> {
  let summary = "Produce a 32-bit integer constant.";
  let arguments = (ins I32Attr:$value);
  let results = (outs I32:$result);
  let assemblyFormat = "$value attr-dict `:` type($result)";
}
```

Field by field:

| Field | Meaning |
|---|---|
| `def Calc_ConstOp : Calc_Op<"const", [...]>` | Defines a record named `Calc_ConstOp`, derived from our `Calc_Op` helper class (which itself is `Op<Calc_Dialect, mnemonic, traits>`). The string `"const"` is the **mnemonic** — what users type after `calc.` |
| `summary` | A short description; surfaced in docs and `--help`. |
| `arguments = (ins ...)` | Inputs to the op. There are two kinds: SSA **operands** (other values, like `arith.addi`'s two inputs) and compile-time **attributes** (like our constant `42`). Both are listed in `(ins ...)`. |
| `results = (outs ...)` | The op's SSA result(s). |
| `assemblyFormat` | The pretty-printer/parser format in a tiny DSL. |

### Operand vs attribute — what's the difference?

| | Operand | Attribute |
|---|---|---|
| Created by | another op | written literally in source / set by builder |
| Form in IR | `%name` | bare literal or `{key = value}` |
| Resolves at | runtime (different value each execution) | compile time (fixed when the op is built) |
| ODS spelling | `AnyType:$name`, `I32:$name`, ... | `I32Attr:$name`, `StrAttr:$name`, ... |

For `calc.const`, the integer value `42` is an **attribute** (a
compile-time literal). It's not produced by another op, it's just
baked into this op.

### Traits

Traits are reusable bits of behavior tacked onto an op. They're how
MLIR tells passes "this op is safe to do X with."

We use one trait this stage: **`Pure`**. It marks the op as having
no side effects and being safely speculatable. Concretely, `Pure` is
shorthand for `[NoMemoryEffect, AlwaysSpeculatable]`, which together
let the canonicalizer / CSE / DCE freely remove, duplicate, or reorder
the op.

Other traits we'll meet in stage 03: `Commutative`,
`SameOperandsAndResultType`. Traits live in
`mlir/Interfaces/SideEffectInterfaces.td` and `mlir/IR/OpBase.td`, which
is why we `include` both.

### The assembly format DSL

The string given to `let assemblyFormat = ...` is parsed by mlir-tblgen
and used to generate *both* the parser and printer for the op.
Directives we use:

| Directive | What it does |
|---|---|
| `$name` | print/parse the operand, attribute, or result named `name` |
| `type($name)` | print/parse the *type* of `name` |
| `attr-dict` | optional `{key = value, ...}` for non-format attributes |
| `` `:` ``, `` `,` ``, `` `(` `` (backticked) | literal punctuation |

Our format `"$value attr-dict ` `:` ` type($result)"` produces:

```
calc.const 42 : i32
```

— literal `42` (the value attribute), no other attrs, then `: i32`
(the result type).

### Bazel: a second `gentbl_cc_library`

We now run mlir-tblgen twice on the same `.td`: once for the dialect
scaffolding, once for the op classes. Different flags, different
outputs:

```python
gentbl_cc_library(
    name = "CalcOpsIncGen",
    strip_include_prefix = ".",
    tbl_outs = [
        (["-gen-op-decls"], "CalcOps.h.inc"),
        (["-gen-op-defs"], "CalcOps.cpp.inc"),
    ],
    tblgen = "@llvm-project//mlir:mlir-tblgen",
    td_file = "CalcDialect.td",
    deps = [":CalcDialectTdFiles"],
)
```

In our hand-written `CalcDialect.h` and `.cpp` we use the
`GET_OP_CLASSES` / `GET_OP_LIST` macros to control what each include
expands to:

```cpp
// In CalcDialect.h — class declarations
#define GET_OP_CLASSES
#include "CalcOps.h.inc"

// In CalcDialect.cpp::initialize() — list of op types
addOperations<
#define GET_OP_LIST
#include "CalcOps.cpp.inc"
    >();
```

This is a standard MLIR idiom — get used to seeing it.

## Glossary (new this stage)

- **Op (operation)** — a single instruction-like unit. Identified by
  its mnemonic (`calc.const`), with operands, results, attributes,
  optional regions.
- **Operand** — an SSA value the op consumes (input).
- **Result** — an SSA value the op produces.
- **Attribute** — compile-time constant data attached to an op (not
  produced by another op).
- **Mnemonic** — the short name of an op within its dialect (`const`
  in `calc.const`).
- **Trait** — a reusable behavior marker (`Pure`, `Commutative`, ...).
- **Assembly format** — the ODS DSL that defines an op's textual
  syntax for parsing and printing.
- **`Pure` trait** — op has no side effects; canonicalization, CSE,
  and DCE may freely remove or duplicate it.
- **`GET_OP_CLASSES` / `GET_OP_LIST`** — preprocessor switches that
  control what `CalcOps.h.inc` / `CalcOps.cpp.inc` expand to in a
  given include context.
- **Round-trip test** — parse a `.mlir` file then immediately print it
  back, checking the printed form matches expectations. Catches bugs
  in both the parser and printer.

## Tasks

One file to edit: `code/CalcDialect.td`. Everything else
(`CalcDialect.h/.cpp`, `calc_opt.cpp`, `BUILD.bazel`, the test) is
ready.

### Task 1 — declare `calc.const`

In `code/CalcDialect.td`, add a `def Calc_ConstOp : Calc_Op<"const",
[Pure]> { ... }` with:

- `summary`
- `arguments = (ins I32Attr:$value)`
- `results = (outs I32:$result)`
- `assemblyFormat = "$value attr-dict ` ``:`` ` type($result)"`

(See the file's comments for hints. If you can't recall the exact
syntax, peek at `solutions/CalcDialect.td`.)

## Running the tests

```bash
bazel test //stage02-first-op/code:round_trip_test
```

Try the binary directly on a sample file:

```bash
# Parse + print (round-trip)
bazel run //stage02-first-op/code:calc-opt -- \
    "$PWD/stage02-first-op/code/round_trip.mlir"
```

You should see the same IR come back out.

## Common mistakes

### `Variable not defined: 'Pure'`

You forgot `include "mlir/Interfaces/SideEffectInterfaces.td"` at the
top of the `.td`. (The stage's boilerplate has it — but if you're
hacking, watch out.)

### Build fails with `expected namespace name`

Same as stage 01 — your `.td` didn't actually generate any classes.
Make sure `def Calc_ConstOp` is present.

### Test fails: `expected operation name in quotes`

This usually means the assembly format mismatches what your test file
writes. The default printer for `I32Attr` prints just the integer
literal, not `42 : i32`. We add `` `:` type($result)`` to the format
to print the result type explicitly. Without that, `calc.const 42`
(no type) is what comes out — and `calc.const 42 : i32` in input
won't parse.

To debug: run `calc-opt` on a generic-form input and see what it
prints back:

```mlir
%x = "calc.const"() {value = 42 : i32} : () -> i32
```

Whatever it prints is your canonical assembly form.

## Inspect the generated op classes

```bash
bazel build //stage02-first-op/code:CalcOpsIncGen
find bazel-bin/stage02-first-op/code -name 'CalcOps.*.inc' \
    -exec wc -l {} \;
```

The generated `CalcOps.cpp.inc` is several hundred lines — accessor
methods, builder helpers, the parser, the printer. ODS just saved you
from writing all of that.

## Next stage

→ Stage 03: `calc.add` and `calc.mul`, with more traits.
