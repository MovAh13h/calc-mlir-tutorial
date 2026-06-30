# Stage 12 — Custom parameterised type (capstone)

## What you'll learn

- How ODS handles **types** vs ops — different base class (`TypeDef`),
  different gen-flags (`-gen-typedef-decls/defs`)
- **Type parameters**: declaring them with C++ types, declaring an
  assembly format for them
- The dialect-level `useDefaultTypePrinterParser` flag and what it
  generates
- Custom **type verifiers** via `genVerifyDecl`
- Idiomatic MLIR type-printing elision (`!calc.fixed<8, 8>` vs `<8, 8>`)

By the end, you'll have `!calc.fixed<int_bits, frac_bits>` — a
parameterised fixed-point number type — plus two ops that use it
(`calc.fconst`, `calc.fadd`).

## Background

### Types vs ops in ODS

In ODS, ops are declared with `def MyOp : Op<...>` and produce a C++
op class. Types are *similar* but use a different base:

```td
def MyType : TypeDef<MyDialect, "MyType"> {
  let mnemonic = "mytype";
  let parameters = (ins "unsigned":$width);
  let assemblyFormat = "`<` $width `>`";
}
```

That produces a C++ class `mlir::mydialect::MyTypeType` (note the
`Type` suffix on the C++ name) with:

- A `get(MLIRContext*, unsigned width)` builder.
- An auto-generated `getWidth()` accessor.
- An auto-generated parser/printer matching the `assemblyFormat`.

### What `useDefaultTypePrinterParser` does

The dialect has one `parseType` / `printType` entry point. When a
custom type is parsed (`!mydialect.something<...>`), MLIR calls
`MyDialect::parseType(parser)` and expects you to dispatch to the
right TypeDef. Writing that dispatcher by hand is annoying.

```td
let useDefaultTypePrinterParser = 1;
```

tells ODS to generate a dispatcher that knows about every `TypeDef`
in the dialect. It reads the type mnemonic, finds the matching
TypeDef class, and routes to its generated parser.

### Type parameters

Parameters look like op `arguments`:

```td
let parameters = (ins "unsigned":$intBits, "unsigned":$fracBits);
```

Each parameter has a **C++ type** (in quotes — a plain string,
because ODS just splats it into the generated `get()` signature) and
a **name** (used by the generated accessor: `getIntBits()`).

You can also have parameters that are themselves MLIR Types,
Attributes, or anything else. For numeric parameters, plain C++
integer types are cleanest.

### Assembly format for the type

```td
let assemblyFormat = "`<` $intBits `,` $fracBits `>`";
```

Same DSL as op assembly format, just smaller. ODS generates both
parser and printer from this string. The dispatcher knows that when
it sees `!calc.fixed`, it should call this type's parser, which
expects `<INT, FRAC>`.

### Printing elision: `!calc.fixed<8, 8>` vs `<8, 8>`

When you print an op like `calc.fconst 256 : !calc.fixed<8, 8>`, the
printer often elides the dialect prefix on the trailing type — so you
get `: <8, 8>`. The same type written in a function signature shows
the full `!calc.fixed<8, 8>`.

Why? In an op's `: <type>` slot, the surrounding context already
implies "an op result"; MLIR's pretty-printer drops the redundant
dialect prefix. In a function signature, the parser needs the full
form because there's no narrower context.

When you write FileCheck for these, match the **short form** for op
results (`: <8, 8>`) and the **full form** for function signatures
(`%arg0: !calc.fixed<8, 8>`).

### Custom type verifier

ODS generates the *declaration* of a type-level verifier when you set
`genVerifyDecl = 1`:

```cpp
LogicalResult
FixedType::verify(function_ref<InFlightDiagnostic()> emitError,
                  unsigned intBits, unsigned fracBits) {
  ...
}
```

`emitError()` returns a diagnostic stream you can `<<` messages into.
The verifier runs once at type construction (so an invalid
`!calc.fixed<8, 0>` fails before any op even sees it).

This is the type analogue of stage 5's `ShrOp::verify()`, but its
context is the *type itself*, not an op.

### `addTypes<...>` in `initialize()`

Same pattern as `addOperations<...>`:

```cpp
void CalcDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "CalcOps.cpp.inc"
      >();
  addTypes<
#define GET_TYPEDEF_LIST
#include "CalcTypes.cpp.inc"
      >();
}
```

If you forget this, the type's C++ class exists but the dialect won't
parse the textual form — you'll get errors like "unknown type
'fixed'" or "expected attribute value."

### Why two ops for one type

`calc.fconst` makes constants of the type, `calc.fadd` does
arithmetic. Both use `Calc_FixedType` as their operand/result type in
ODS — the auto-generated parser will accept anything that parses as
`!calc.fixed<N, M>` for that slot.

We're not lowering this to anything in this stage; the goal is purely
type mechanics. (A real implementation would lower `calc.fadd %a, %b`
on `!calc.fixed<8, 8>` to `arith.addi %a, %b : i16`, and `calc.fconst`
to `arith.constant`.)

## Glossary (new this stage)

- **TypeDef** — ODS class for defining custom types, analogous to
  `Op` for operations.
- **Type parameters** — fields a parameterised type carries (e.g.
  `intBits`, `fracBits`).
- **Type mnemonic** — the short identifier after the dialect name in
  textual IR (`!calc.fixed` ← `"fixed"` is the mnemonic).
- **`useDefaultTypePrinterParser`** — dialect flag to auto-generate
  the parseType/printType dispatcher.
- **`addTypes<...>`** — registers TypeDef classes with the dialect.
- **`genVerifyDecl`** — TypeDef flag to declare a type-level verifier.
- **Q8.8 / Q4.4 / Q16.16** — fixed-point notation: `QM.N` means M int
  bits + N frac bits.

## Tasks

Five small TODOs across two files:

### Task 1 — dialect flag

In `code/CalcDialect.td`, add `let useDefaultTypePrinterParser = 1;`
inside `def Calc_Dialect`.

### Task 2 — `Calc_Type` base + `Calc_FixedType`

In `code/CalcDialect.td`, add the `Calc_Type` helper class and the
`def Calc_FixedType : Calc_Type<"Fixed", "fixed">` record. Template
in the file's TODO.

### Task 3 — two ops using the new type

In `code/CalcDialect.td`, add `Calc_FConstOp` and `Calc_FAddOp`.
Template in the file's TODO.

### Task 4 — `addTypes<...>` in `initialize()`

In `code/CalcDialect.cpp`, add the `addTypes<...>` call inside
`CalcDialect::initialize()`.

### Task 5 — `FixedType::verify`

In `code/CalcDialect.cpp`, implement the verifier. Reject `fracBits ==
0` and total widths outside `{8, 16, 32, 64}`.

## Running the tests

```bash
bazel test //stage12-custom-type/code/...
```

Two new tests:

- `fixed_round_trip_test` — exercises parsing/printing the type and
  the two ops at Q8.8, Q4.4, Q16.16.
- `fixed_verify_test` — confirms the verifier rejects fracBits=0
  and weird widths.

Plus all 10 carryovers from stages 00–11 still apply.

Interactive sanity check:

```bash
bazel run //stage12-custom-type/code:calc-opt -- \
    "$PWD/stage12-custom-type/code/fixed_round_trip.mlir"
```

You should see the input round-tripped, with `!calc.fixed<8, 8>` in
function signatures and `<8, 8>` after op results.

## Common mistakes

### "unknown type 'fixed'" at parse time

You forgot `addTypes<...>` in `initialize()` (Task 4), or your dialect
doesn't have `useDefaultTypePrinterParser = 1` (Task 1). Both are
required.

### Build error: "no type named 'FixedType' in namespace 'mlir::calc'"

You haven't defined `Calc_FixedType` in the .td yet (Task 2), or the
gen-typedef-decls rule isn't producing `CalcTypes.h.inc`. The BUILD
file is already wired; check that `Calc_FixedType` syntax matches the
template.

### CHECK fails because `!calc.fixed<8, 8>` doesn't appear in output

The printer elides the dialect prefix on op-result type slots. Use
the short form `<8, 8>` in CHECK lines for `: <type>` slots; use the
full `!calc.fixed<8, 8>` only for function signatures.

### Verifier seems to run twice / error appears twice

Each `// -----` block in `fixed_verify.mlir` is a separate snippet
under `--split-input-file`. You should see each `expected-error`
match exactly one diagnostic.

### "expected attribute value" when parsing `!calc.fixed<8, 8>`

The dialect tried to parse `fixed` as an attribute mnemonic because
there's no matching TypeDef registered. Usually a typo in the
mnemonic between the .td (`let mnemonic = "fixed"`) and the
test file (`!calc.fixed<...>`).

### Confusing C++ name: `FixedType` vs `Calc_FixedType`

The ODS def is `def Calc_FixedType` — that's the *TableGen* record
name. The C++ class name is the TypeDef's first template argument:
`TypeDef<Calc_Dialect, "Fixed">` → `mlir::calc::FixedType` (note the
appended `Type`). Use the C++ name in `CalcDialect.cpp`.

## Try this

1. Add a `calc.fixed_to_i32` op that bit-casts a `!calc.fixed<I, F>`
   to a plain i32 (when `I + F == 32`). This is the bridge for
   lowering to arith.
2. Make `Calc_FixedType` accept a parameter list with a default
   (`let parameters = (ins "unsigned":$intBits, DefaultValuedParameter<"unsigned", "0">:$fracBits)`).
3. Add a `calc.fmul` that computes `(a * b) >> fracBits` — the proper
   fixed-point multiply. (Hint: you'll need to know the type's
   `fracBits` inside the lowering; type accessors are available.)

## Wrap-up

That's the end of the tutorial. You've built:

| | |
|---|---|
| **Dialect** | `calc`, registered via ODS, with full `mlir-opt` integration |
| **Ops** | `const`, `add`, `mul`, `print`, `shr`, `fconst`, `fadd` |
| **Types** | `i32` (built-in) + `!calc.fixed<int, frac>` (custom, parameterised) |
| **Traits** | `Pure`, `Commutative`, `SameOperandsAndResultType`, `ConstantLike`, `MemoryEffects<[MemWrite]>` |
| **Verifiers** | op (`ShrOp::verify`) + type (`FixedType::verify`) + `--verify-diagnostics` test harness |
| **Folds** | `ConstOp`, `AddOp`, `MulOp` — wired via `ConstantLike` + `materializeConstant` |
| **Canonicalization** | DRR patterns (`x+0→x`, `x*1→x`, `x*0→0`) |
| **Custom pass** | `--calc-strength-reduce` with hand-written `OpRewritePattern` |
| **Conversion** | partial conversion `calc→arith`, full conversion via chain to LLVM dialect |
| **Execution** | end-to-end JIT via `mlir-cpu-runner`, real `printf` output |

From here, the natural next steps in MLIR are:
- Build a non-trivial dialect (something with regions, like `scf`)
- Read about `Interfaces` for op behavior beyond traits
- Explore the bufferization and tensor lowering passes (the "real
  workload" of MLIR)
- Look at `mlir-translate` exporters/importers if you need to plug
  into an existing IR

The patterns you used here scale up.
