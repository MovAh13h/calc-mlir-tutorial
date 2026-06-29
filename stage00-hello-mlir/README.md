# Stage 00 — Hello MLIR

## What you'll learn

- What MLIR actually is, in concrete terms
- The shape of a `.mlir` file (functions, ops, values, types)
- What `mlir-opt` does
- How tests are wired in this tutorial

This stage uses **only built-in dialects** (`func`, `arith`). You won't
define any new ops yet — first you need to know what an op *looks like*.

## Background

### MLIR in one paragraph

MLIR is a framework for building compiler intermediate representations
(IRs). Unlike LLVM IR — which has *one* fixed instruction set — MLIR
lets you define multiple, layered IRs called **dialects** that can
coexist in the same file. Code typically starts in a high-level dialect
(close to your source language) and is progressively *lowered* through
intermediate dialects down to the `llvm` dialect, which is essentially
a one-to-one mapping of LLVM IR.

### Anatomy of a `.mlir` file

```mlir
func.func @main() -> i32 {
  %c5 = arith.constant 5 : i32
  %c7 = arith.constant 7 : i32
  %sum = arith.addi %c5, %c7 : i32
  return %sum : i32
}
```

Things to notice:

- **`func.func`** is an *op* from the `func` dialect. It carries a
  *region* containing a *block* of more ops.
- **`%c5`, `%sum`** are *values*. They start with `%` and are SSA — each
  is defined exactly once.
- **`arith.constant`** is an op from the `arith` dialect. It has no
  operands but produces one result (`%c5`).
- **`arith.addi`** takes two operand values (`%c5`, `%c7`) and produces
  one result (`%sum`).
- **`: i32`** is a type annotation. Most values are typed inline.
- **`return`** here is short for `func.return` (the parser resolves the
  short form to the dialect that's currently providing the function-like
  context).

That's most of MLIR's surface syntax. Everything else is just more ops.

### What `mlir-opt` does

`mlir-opt` is *the* tool for processing `.mlir` files. You give it
input IR and optionally a list of passes; it prints transformed IR.

```bash
# Just parse and print (round-trip)
mlir-opt input.mlir

# Run the canonicalizer pass
mlir-opt --canonicalize input.mlir

# Run an entire pipeline
mlir-opt --pass-pipeline='builtin.module(func.func(canonicalize,cse))' input.mlir
```

Round-tripping with no passes is a useful sanity check: if `mlir-opt`
can parse your file and print it back, the syntax is valid.

### How tests work in this tutorial

Each test is a `.mlir` file with `// CHECK*` comment directives. The
test runner (`common/run_filecheck.sh`) does:

```
mlir-opt [args] <file.mlir> | FileCheck <file.mlir>
```

`FileCheck` scans the `.mlir` file for `// CHECK:` lines and verifies
they appear in order in `mlir-opt`'s output. A few useful directives:

| Directive | Meaning |
|---|---|
| `// CHECK: foo` | The next checked line must contain `foo`. |
| `// CHECK-LABEL: bar` | Resync FileCheck to a line containing `bar`. Used to anchor to a function. |
| `// CHECK-NEXT: baz` | Must appear on the line *immediately* after the previous match. |
| `// CHECK-NOT: bad` | Must *not* appear between this and the next CHECK. |
| `%[[X:.*]]` | Capture an SSA name into variable `X` for later use. |
| `%[[X]]` | Reference a previously captured variable. |

We use FileCheck variable capture because MLIR doesn't promise to
preserve SSA value names — `%foo` you wrote might come out as `%0`.
Capturing makes tests robust to renaming.

## Glossary (new this stage)

- **`func` dialect** — built-in dialect providing function-like ops:
  `func.func` (define), `func.call`, `func.return`.
- **`arith` dialect** — built-in dialect of basic arithmetic ops on
  integer and float types: `arith.constant`, `arith.addi`, `arith.muli`,
  etc.
- **SSA** — Static Single Assignment. Every value is defined exactly
  once. Familiar from LLVM IR.
- **Round-trip** — parse a `.mlir` file with `mlir-opt` and print it
  back. If output parses back to the same IR, the dialect's printer and
  parser are consistent.

## Tasks

Open `code/hello.mlir`. You'll see two functions with `TODO` bodies and
`// CHECK*` directives describing what they should look like once
implemented.

### Task 1 — fix `main`

`main` should return the constant `42` as an `i32`. Currently it
returns `0`. Change the constant.

### Task 2 — implement `add_five`

`add_five(%x: i32) -> i32` should return `%x + 5`. You'll need:

- An `arith.constant 5 : i32` to get the literal `5`
- An `arith.addi %x, %c5 : i32` to add them
- A `return` of the result

## Running the tests

From the repo root:

```bash
# Run both code/ (you, while learning) and solutions/ tests
bazel test //stage00-hello-mlir/...

# Just your work-in-progress
bazel test //stage00-hello-mlir/code:hello_test

# Just the solution (always passes)
bazel test //stage00-hello-mlir/solutions:hello_test
```

To see what `mlir-opt` actually outputs for your file (without
FileCheck), run it directly:

```bash
bazel run @llvm-project//mlir:mlir-opt -- \
    "$PWD/stage00-hello-mlir/code/hello.mlir"
```

This is invaluable for debugging FileCheck failures: paste the output
side-by-side with the CHECK lines and you'll see what didn't match.

## Common mistakes

- **Forgot the type annotation.** Almost everything in MLIR needs a
  `: <type>` somewhere.
- **`return` without a result.** `func.func @foo() -> i32` *must*
  return an `i32`. The verifier will yell if it doesn't.
- **Using a value before it's defined.** SSA means definitions come
  before uses, top-to-bottom.
- **Wrong dialect prefix.** It's `arith.constant`, not
  `arith.const` or `constant`.

## If you get stuck

Peek at `solutions/hello.mlir`. The solution and the boilerplate share
the same CHECK lines, so the only differences are the function bodies.

## Next stage

→ Stage 01 (coming up): define an empty `calc` dialect of your own.
