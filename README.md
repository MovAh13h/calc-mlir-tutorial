# MLIR Tutorial — building the `calc` dialect from scratch

A hands-on, stage-by-stage walkthrough of MLIR for someone who knows the
*words* (dialect, op, pass, lowering, pattern) but hasn't actually used
any of them. By the end you'll have built a tiny `calc` dialect, written
canonicalization patterns and a pass, lowered it all the way to LLVM IR,
and JIT-executed it.

The example dialect is deliberately trivial — one type (`i32`), four ops
(`const`, `add`, `mul`, `print`) — so you can focus on MLIR mechanics
instead of language semantics.

## How to use this tutorial

Each stage lives in its own directory `stageNN-…/` and is fully
self-contained:

```
stageNN-…/
├── README.md     ← read this first
├── code/         ← starting boilerplate with `TODO` markers
├── solutions/    ← reference implementation, peek when stuck
└── tests/        ← run these to know you've done it right
```

Workflow per stage:

1. Read the stage's `README.md`.
2. Edit files in `code/` to do the tasks.
3. Run the tests until they pass.
4. If stuck, compare against `solutions/`.

Stages build on each other conceptually, but each stage's `code/` is a
fresh snapshot — you don't need to keep your previous stage's work
around. (Stage `N`'s `code/` is roughly equivalent to stage `N-1`'s
`solutions/` with new TODOs added.)

## Roadmap

| # | Stage | What you'll learn |
|---|---|---|
| 00 | [Hello MLIR](stage00-hello-mlir/) | Toolchain, `.mlir` syntax, running `mlir-opt` |
| 01 | [Empty `calc` dialect](stage01-empty-dialect/) | ODS basics, dialect registration, Bazel tablegen wiring, custom `calc-opt` driver |
| 02 | [`calc.const`](stage02-first-op/) | First op, attribute vs operand, assembly format, round-trip testing |
| 03 | [`calc.add` + `calc.mul`](stage03-more-ops/) | Binary ops, traits (`Pure`, `Commutative`, `SameOperandsAndResultType`) |
| 04 | [`calc.print`](stage04-side-effects/) | Side-effecting ops, `MemoryEffects<[MemWrite]>`, DCE preservation |
| 05 | [Verifiers](stage05-verifiers/) | `calc.shr` with `hasVerifier`, custom `verify()`, `--verify-diagnostics` |
| 06 | [Canonicalization with DRR](stage06-canonicalization/) | Declarative rewrite patterns: `x+0→x`, `x*1→x`, `x*0→0` |
| 07 | [Fold methods](stage07-folders/) | `hasFolder`, `ConstantLike`, `materializeConstant`; `1+2→3`, chained folds |
| 08 | A custom pass | Walking IR, pass registration, running with `mlir-opt` |
| 09 | Conversion to `arith` | `ConversionTarget`, type converters, partial vs full conversion |
| 10 | Conversion to LLVM dialect | Lowering to LLVM dialect, `mlir-translate` to LLVM IR |
| 11 | End-to-end execution | `.mlir` → JIT via `mlir-cpu-runner`; `calc.print` via `printf` |
| 12 | *(optional)* Custom type | Fixed-point `calc.fixed<int,frac>` capstone |

## Build system

This project uses **Bazel** with the LLVM 17 BCR module
(`MODULE.bazel`). All MLIR/LLVM targets come from `@llvm-project//mlir`
and `@llvm-project//llvm`.

### Cheat-sheet

```bash
# Build a target
bazel build //stage00-hello-mlir/...

# Run tests for a stage
bazel test //stage00-hello-mlir/...

# Run mlir-opt manually (after building once)
bazel run @llvm-project//mlir:mlir-opt -- --help

# Refresh compile_commands.json for clangd
bazel run //:refresh_compile_commands
```

The first build is slow — Bazel will fetch and compile LLVM/MLIR. Plan
for 30+ minutes on the first run. Subsequent builds are incremental and
fast.

## Glossary

Terms in roughly the order they appear in the tutorial.

- **MLIR** — Multi-Level Intermediate Representation. A framework for
  building compiler IRs. Comes from LLVM.
- **Operation (op)** — The fundamental unit of computation in MLIR.
  Examples: `arith.addi`, `func.call`, our future `calc.add`. An op has
  operands (inputs), results (outputs), attributes (compile-time
  constants), and may contain regions.
- **Type** — The type of a value (an operand or result). E.g. `i32`,
  `f64`, `tensor<4xi32>`, or a custom type you define.
- **Attribute** — Compile-time constant data attached to an op. E.g. the
  literal value `42` in `arith.constant 42 : i32` is an attribute, not
  an operand.
- **Region** — A nested area inside an op that contains blocks. Lets ops
  like `func.func` or `scf.if` carry executable bodies.
- **Block** — A sequence of ops ending in a terminator (e.g.
  `func.return`). Blocks live inside regions.
- **Dialect** — A logical grouping of ops, types, and attributes under a
  namespace. `arith`, `func`, `scf`, `llvm` are all built-in dialects.
  You're going to build one called `calc`.
- **ODS** — Operation Definition Specification. A DSL (built on
  TableGen) for declaring dialects, ops, types, and attributes in `.td`
  files. Generates C++ boilerplate.
- **TableGen / tblgen** — The LLVM code-generation tool that consumes
  `.td` files. `mlir-tblgen` is its MLIR-aware flavor.
- **Trait** — A reusable behavior tag attached to an op declaration.
  Examples: `Pure` (op has no side effects, can be removed if unused),
  `Commutative` (operand order doesn't matter).
- **Verifier** — A check that an op is well-formed (types match, count
  of operands is correct, etc.). Some are derived from traits; some you
  write by hand.
- **Pattern (rewrite pattern)** — A rule that transforms one piece of IR
  into another. Used for canonicalization, optimization, and conversion.
- **DRR** — Declarative Rewrite Rule. A way to express simple rewrite
  patterns directly in ODS, without C++.
- **Canonicalization** — A standard MLIR transformation that applies
  registered rewrite patterns to simplify IR (e.g. `x + 0 → x`).
- **Pass** — A transformation that walks the IR and changes it. Runs as
  part of a pass pipeline. `--canonicalize` and `--cse` are built-in
  passes.
- **Lowering / Conversion** — The act of translating ops from one
  dialect to ops in another (usually lower-level) dialect. E.g.
  `calc.add` → `arith.addi` → `llvm.add`.
- **ConversionTarget** — During a dialect conversion, declares which
  dialects/ops are *legal* (allowed in the output IR) vs *illegal* (must
  be converted away).
- **Partial vs full conversion** — A partial conversion is OK with some
  illegal ops surviving; a full conversion fails if any illegal op
  remains.
- **`mlir-opt`** — The driver tool for running passes on `.mlir` files.
- **`mlir-translate`** — Converts MLIR IR to/from external formats
  (LLVM IR, SPIR-V, etc.).
- **`mlir-cpu-runner`** — JIT-executes a `.mlir` file end-to-end.
- **FileCheck** — LLVM's pattern-matching test tool. Reads `// CHECK:`
  comments from a test file and verifies they appear in the output of
  some other command (typically `mlir-opt`).

## Start here

→ [Stage 00: Hello MLIR](stage00-hello-mlir/)
