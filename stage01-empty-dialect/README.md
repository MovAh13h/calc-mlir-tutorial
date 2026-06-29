# Stage 01 — Your first dialect (empty)

## What you'll learn

- What a **dialect** actually is (a C++ class) and how ODS generates it
- How `mlir-tblgen` produces C++ from `.td` files
- How to wire up the Bazel `td_library` + `gentbl_cc_library` pair
- How to build a custom `mlir-opt`-style binary (`calc-opt`) that
  registers your dialect

By the end of this stage you'll have a `calc` dialect that's
**registered with MLIR** but has **zero ops** in it. We need the empty
shell first; ops come in stage 02.

## Background

### A dialect is a C++ class

When you read MLIR docs, "dialect" sounds abstract. Concretely a
dialect is a C++ class deriving from `mlir::Dialect`, with:

- a string `name` (e.g. `"calc"`) — the prefix in op names
- a C++ namespace (e.g. `::mlir::calc`)
- an `initialize()` method that registers all the dialect's ops, types,
  and attributes

You *could* write that class by hand. Nobody does, because the
declaration is mechanical: name string, constructor, `initialize()`
prototype. Instead you declare the dialect in **ODS** and `mlir-tblgen`
generates the C++ for you.

### ODS in 30 seconds

ODS (Operation Definition Specification) is the DSL built on TableGen
that MLIR uses to describe dialects/ops/types/attributes. ODS files
have extension `.td`. They look like this:

```td
include "mlir/IR/OpBase.td"

def Calc_Dialect : Dialect {
  let name = "calc";
  let summary = "A tutorial dialect for arithmetic over i32.";
  let cppNamespace = "::mlir::calc";
}
```

`def Calc_Dialect : Dialect { ... }` says "create a record named
`Calc_Dialect` derived from the built-in `Dialect` class, with these
fields set." `mlir-tblgen` consumes this and produces C++.

### What `mlir-tblgen` actually generates

For our `.td`, two invocations:

```
mlir-tblgen -gen-dialect-decls CalcDialect.td  →  CalcDialect.h.inc
mlir-tblgen -gen-dialect-defs  CalcDialect.td  →  CalcDialect.cpp.inc
```

The `.h.inc` declares roughly:

```cpp
namespace mlir { namespace calc {
class CalcDialect : public ::mlir::Dialect {
  /* ... constructor, getDialectNamespace(), etc. ... */
  void initialize();
};
}}
```

The `.cpp.inc` defines the constructor and supporting bits. *You* still
have to:

- Write `CalcDialect.h` that `#include`s the generated `.h.inc`
- Write `CalcDialect.cpp` that `#include`s the generated `.cpp.inc` and
  implements `initialize()`

These are tiny wrappers — a few lines each.

### The Bazel side: `td_library` + `gentbl_cc_library`

Two macros from `@llvm-project//mlir:tblgen.bzl`:

- **`td_library`** — declares a group of `.td` files and what they
  depend on (e.g. `OpBaseTdFiles`, where the base `Dialect` class lives).
- **`gentbl_cc_library`** — runs `mlir-tblgen` on a `.td` file with
  given flags to produce `.h.inc` / `.cpp.inc` files, and wraps the
  result as a `cc_library` that downstream `cc_library`s can depend on.

We use `strip_include_prefix = "."` so that downstream code can
`#include "CalcDialect.h.inc"` by basename instead of by full
repo-relative path.

### A custom `mlir-opt` (`calc-opt`)

The stock `@llvm-project//mlir:mlir-opt` doesn't know our dialect
exists. To use our dialect with `mlir-opt`-style tooling, we link our
own tiny driver:

```cpp
int main(int argc, char **argv) {
  mlir::DialectRegistry registry;
  mlir::registerAllDialects(registry);   // built-ins
  mlir::registerAllPasses();
  registry.insert<mlir::calc::CalcDialect>();  // ← our dialect
  return mlir::asMainReturnCode(
      mlir::MlirOptMain(argc, argv, "calc-opt", registry));
}
```

`MlirOptMain` is the entire mlir-opt CLI as a library function. We pass
it the registry; it handles argument parsing, IR loading, pass running,
printing. The result is an executable that behaves exactly like
`mlir-opt` plus knows about `calc`.

## Glossary (new this stage)

- **ODS** — Operation Definition Specification. The MLIR DSL on top of
  TableGen.
- **TableGen / tblgen** — generic LLVM code generator. `mlir-tblgen` is
  the MLIR-aware variant.
- **`Dialect` (the ODS class)** — the base record in
  `mlir/IR/OpBase.td` that your `def Foo_Dialect : Dialect { ... }`
  derives from.
- **`initialize()`** — the method MLIR calls once when your dialect is
  loaded into a context. Future stages will populate it with
  `addOperations<...>()`, `addTypes<...>()`, etc.
- **`MlirOptMain`** — the library version of `mlir-opt`'s `main()`.
  Wrap it in your own `main()`, give it a registry, and you get a
  fully-functional custom `mlir-opt`.
- **Dialect registry** — a collection of dialects that an `MLIRContext`
  is allowed to load. `registry.insert<MyDialect>()` adds yours.

## Tasks

There's exactly one file you need to edit: `code/CalcDialect.td`.
Everything else (BUILD, C++ wrappers, calc-opt driver) is provided.

### Task 1 — write the dialect definition

Open `code/CalcDialect.td`. Add a `def Calc_Dialect : Dialect { ... }`
block setting:

- `let name = "calc";`
- `let summary = "<anything one-line>";`
- `let cppNamespace = "::mlir::calc";`

`cppNamespace` must be exactly `::mlir::calc` because the
hand-written `.cpp` and `.h` reference `mlir::calc::CalcDialect`. If
you change it, the build breaks.

## Running the test

```bash
bazel test //stage01-empty-dialect/code:calc_dialect_registered_test
```

A passing run looks like:

```
INFO: //stage01-empty-dialect/code:calc_dialect_registered_test PASSED
```

You can also poke at the binary directly:

```bash
bazel run //stage01-empty-dialect/code:calc-opt -- --show-dialects
```

You should see `calc` in the comma-separated list.

## Common mistakes

### `error: expected namespace name` / `use of undeclared identifier 'CalcDialect'`

This means the `.td` didn't actually define `Calc_Dialect`, so the
generated `.h.inc` is empty (or missing `CalcDialect`), so
`mlir::calc::CalcDialect` doesn't exist. Make sure you wrote the
`def Calc_Dialect : Dialect { ... }` block.

### Test fails with `dialect 'calc' not registered`

The `.td` compiled successfully, but the dialect's `name` field isn't
`"calc"`. Check the spelling — it must be lowercase `"calc"`.

### `cppNamespace` mismatch

Anything other than `"::mlir::calc"` will break the build, because the
hand-written `CalcDialect.cpp` says `using namespace mlir::calc;` and
defines `mlir::calc::CalcDialect::initialize()`.

## How to inspect the generated code

If you're curious what `mlir-tblgen` produced:

```bash
bazel build //stage01-empty-dialect/code:CalcDialectIncGen
find bazel-bin/stage01-empty-dialect/code -name 'CalcDialect.*.inc'
```

You'll see the auto-generated class declaration and constructor.

## Next stage

→ Stage 02: define `calc.const`, the first op in our dialect.
