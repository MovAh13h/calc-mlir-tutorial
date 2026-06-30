# Stage 10 — Conversion to the LLVM dialect

## What you'll learn

- The **LLVM dialect**: an in-MLIR mirror of LLVM IR that you can run
  passes on before exporting
- Inserting **external function declarations** and **global constants**
  programmatically (`llvm.func @printf`, `llvm.mlir.global @fmt`)
- Lowering a side-effecting op (`calc.print`) to an `llvm.call`
- Chaining your custom lowering with stock lowerings
  (`--convert-arith-to-llvm`, `--convert-func-to-llvm`)
- Opaque vs typed LLVM pointers in MLIR 17, and the bitcast bridge

By the end, the chain
```
--calc-to-arith --calc-print-to-llvm
--convert-arith-to-llvm --convert-func-to-llvm
--reconcile-unrealized-casts
```
turns a calc-dialect program into a fully LLVM-dialect program — ready
for `mlir-translate` (or, in stage 11, `mlir-cpu-runner` for actual
JIT execution).

## Background

### The LLVM dialect, briefly

The LLVM dialect is a dialect *inside* MLIR whose ops correspond
one-to-one with LLVM IR constructs:

| LLVM IR | LLVM dialect (in MLIR) |
|---|---|
| `add i32 %a, %b` | `llvm.add %a, %b : i32` |
| `i32 (i8*, ...) printf` | `llvm.func @printf(!llvm.ptr, ...) -> i32` |
| `@fmt = constant [4 x i8] c"%d\n\00"` | `llvm.mlir.global internal constant @fmt("%d\n\00")` |
| `getelementptr` | `llvm.getelementptr` |
| `call` | `llvm.call` |

You manipulate it with the same tools (passes, patterns) you've been
using all stage. Once everything is in the LLVM dialect, `mlir-translate
--mlir-to-llvmir` emits actual LLVM IR text.

### The printf prelude

To print an integer, your final IR needs:

```mlir
llvm.mlir.global internal constant @calc_print_fmt("%d\0A\00")
llvm.func @printf(!llvm.ptr, ...) -> i32
```

These get emitted once per module by our pass — we walk the module
and insert them if not already present. (Subsequent calls reuse the
same decl + global.)

### Lowering one calc.print

```mlir
calc.print %v : i32
```

becomes

```mlir
%a = llvm.mlir.addressof @calc_print_fmt : !llvm.ptr<array<4 x i8>>
%f = llvm.bitcast %a : !llvm.ptr<array<4 x i8>> to !llvm.ptr
%_ = llvm.call @printf(%f, %v) : (!llvm.ptr, i32) -> i32
```

The bitcast bridges typed and opaque pointer types (see below).

### Opaque pointers in LLVM 17

LLVM IR moved to *opaque pointers* in v15 — `ptr` instead of `i8*`,
`i32*`, etc. The MLIR LLVM dialect supports both modes:

- `LLVM::AddressOfOp::build(loc, global)` returns a **typed**
  pointer to the global's storage type
  (`!llvm.ptr<array<4 x i8>>` here).
- `LLVM::LLVMPointerType::get(ctx)` (no element type) is the
  **opaque** pointer.

When you mix sources — some typed, some opaque — you get type-mismatch
errors. The cleanest fix is to keep the *interface* (printf's
signature) opaque, and convert the addressof result with an
`llvm.bitcast`. After mlir-translate emits LLVM IR (which is opaque-pointer
in LLVM 17), the bitcast becomes a no-op.

(Alternative: drop down a level and use `LLVMTypeConverter` with
`useOpaquePointers=true`; or use a `getelementptr` with zero indices
to get `!llvm.ptr` from a `!llvm.ptr<array...>`. The bitcast is the
simplest for a tutorial.)

### Walking and modifying a module from a pass

Our pass needs to do *more* than rewrite individual ops — it has to
add things (decl, global) at module scope. The pattern:

```cpp
void runOnOperation() override {
  ModuleOp module = getOperation();

  // Walk to see if we need to do anything at all.
  bool hasPrint = false;
  module.walk([&](PrintOp) {
    hasPrint = true;
    return WalkResult::interrupt();
  });
  if (!hasPrint) return;

  // Insert module-level symbols.
  LLVM::LLVMFuncOp printf = ensurePrintfDecl(module);
  LLVM::GlobalOp fmt      = ensureFormatString(module);

  // Rewrite the calc.print ops.
  RewritePatternSet patterns(&getContext());
  patterns.add<PrintOpLowering>(&getContext(), printf, fmt);
  if (failed(applyPatternsAndFoldGreedily(module, std::move(patterns))))
    signalPassFailure();
}
```

Two new tricks:

1. **`module.walk(...)`** — visits every op in the module. The
   templated callable form deduces the op type and only fires on
   matching ops.
2. **Patterns with state** — `PrintOpLowering`'s constructor takes
   `printf` and `fmt`; we pass them through `patterns.add<>(...)`.

### The full pipeline

Once calc.print is gone and arith ops are present, the remaining
lowerings are stock:

| Pass | Removes | Adds |
|---|---|---|
| `--calc-to-arith` | calc.const/add/mul/shr | arith.constant/addi/muli/shrui |
| `--calc-print-to-llvm` | calc.print | llvm.call @printf, llvm.mlir.global, llvm.func |
| `--convert-arith-to-llvm` | arith.* | llvm.add/mul/etc., llvm.mlir.constant |
| `--convert-func-to-llvm` | func.func / func.return | llvm.func / llvm.return |
| `--reconcile-unrealized-casts` | unrealized_conversion_cast | (nothing — cleanup) |

The order matters: calc.print must lower before arith/func because
the lowering inserts ops into `func.func` (which only exists pre-conversion).

`--reconcile-unrealized-casts` is needed because the func/llvm boundary
sometimes inserts `unrealized_conversion_cast` ops to bridge type
remappings; this pass resolves them when both sides have agreed on
the final type.

## Glossary (new this stage)

- **LLVM dialect** — the MLIR dialect that mirrors LLVM IR ops/types.
- **`llvm.func`** — function declaration/definition in the LLVM
  dialect.
- **`llvm.mlir.global`** — a global variable (module-scope constant
  or mutable). Initial value is an attribute.
- **`llvm.mlir.addressof`** — produces a pointer to a global.
- **`llvm.call`** — call instruction; first operand is callee
  (symbol ref).
- **`llvm.bitcast`** — pointer cast (and other no-op casts).
- **Opaque pointer** — `!llvm.ptr` with no element type — the modern
  LLVM IR convention.
- **`mlir-translate`** — tool that converts the LLVM dialect to actual
  LLVM IR text (use `--mlir-to-llvmir`).

## Tasks

Five TODOs across `code/CalcPasses.td` and `code/CalcPasses.cpp`.

### Task 1 — declare the pass

In `code/CalcPasses.td`, add the `def CalcPrintToLLVM : Pass<...>`
record. Template in the file's TODO.

### Task 2 — `ensurePrintfDecl`

Look up `@printf` in the module; if missing, create it with signature
`i32 (ptr, ...)`. Return the op.

### Task 3 — `ensureFormatString`

Look up `@calc_print_fmt`; if missing, create it as an internal
constant LLVM global holding `"%d\n\0"`.

### Task 4 — `PrintOpLowering::matchAndRewrite`

Build `addressof` → `bitcast` → `llvm.call @printf(fmt, value)`, then
erase the original calc.print.

### Task 5 — `runOnOperation`

Walk for any calc.print; early-out if none. Otherwise ensure the
prelude, build the pattern set, run the greedy driver.

## Running the tests

```bash
bazel test //stage10-llvm-conversion/code/...
```

Two new tests:

- `print_to_llvm_test` — just `--calc-print-to-llvm` on a small input
- `full_pipeline_test` — the whole chain producing pure LLVM dialect IR

Plus the seven carryovers (round_trip, dce, verify, canonicalize, fold,
strength_reduce, calc_to_arith) — none should regress.

Inspect the pipeline interactively:

```bash
bazel run //stage10-llvm-conversion/code:calc-opt -- \
    --calc-to-arith --calc-print-to-llvm \
    --convert-arith-to-llvm --convert-func-to-llvm \
    --reconcile-unrealized-casts \
    "$PWD/stage10-llvm-conversion/code/full_pipeline.mlir"
```

You should see no `calc.`, `arith.`, or `func.` ops in the output —
only `llvm.*`.

To dump the final LLVM IR (text), pipe through `mlir-translate`:

```bash
bazel run //stage10-llvm-conversion/code:calc-opt -- \
    --calc-to-arith --calc-print-to-llvm \
    --convert-arith-to-llvm --convert-func-to-llvm \
    --reconcile-unrealized-casts \
    "$PWD/stage10-llvm-conversion/code/full_pipeline.mlir" |
bazel run @llvm-project//mlir:mlir-translate -- --mlir-to-llvmir
```

That output is real LLVM IR text — you could feed it to `llc` or
`opt` and get a working binary.

## Common mistakes

### Build error: `unknown template name 'CalcPrintToLLVMBase'`

You haven't done **Task 1** yet — without the `def CalcPrintToLLVM :
Pass<...>` in the `.td`, `CalcPasses.h.inc` has no
`CalcPrintToLLVMBase` definition. Add the pass declaration and rebuild.

### "operand type mismatch for operand 0: '!llvm.ptr<array<4 x i8>>' != '!llvm.ptr'"

You're passing the raw `AddressOfOp` result (typed pointer) to
`printf` (which takes opaque `!llvm.ptr`). Add an `llvm.bitcast`
between them.

### "redefinition of symbol named 'printf'" or 'calc_print_fmt'

You're not looking up the symbol before creating it; each run of the
pattern (per print op) adds another decl/global. Use
`module.lookupSymbol<LLVM::LLVMFuncOp>("printf")` first and skip if
present.

### `llvm.func @printf(...)` is missing from output

You never *call* `ensurePrintfDecl` — usually because the early-out
returned without doing anything. Or your `module.walk` predicate is
wrong and `hasPrint` stays false.

### "dialect 'llvm' not loaded"

Forgot `dependentDialects = ["::mlir::LLVM::LLVMDialect"]` on the
pass def. Even when you import the header (which makes the C++ class
available), the dialect must be loaded into the MLIRContext before
ops from it can be created.

### Driver loops forever

Same trap as stage 08: `matchAndRewrite` returning `success()` without
actually mutating IR via the rewriter. Make sure every `success()`
path either calls `rewriter.replaceOp*`, `rewriter.eraseOp`, or
`rewriter.create<...>` for a substitute.

### "failed to legalize 'func.return'" with `--convert-func-to-llvm`

Some interaction with `--convert-arith-to-llvm` running first. The
chain order we use (`calc-to-arith` → `calc-print-to-llvm` →
`convert-arith-to-llvm` → `convert-func-to-llvm` →
`reconcile-unrealized-casts`) is the order that works for our setup.
Don't shuffle.

## Try this

1. Make printf take a typed `!llvm.ptr<i8>` instead of opaque
   `!llvm.ptr`, and use `llvm.getelementptr` (with zero indices) to
   convert from `!llvm.ptr<array<4 x i8>>`. Compare the IR.
2. Add a second format string for hex (`"0x%x\n\0"`) and a
   `calc.print_hex` op that uses it. (You'll need to extend the
   dialect a tiny bit.)
3. Run the output through `mlir-translate --mlir-to-llvmir` and then
   `clang -x ir - -o calc_program` — congrats, you compiled a calc
   program.

## Next stage

→ Stage 11: end-to-end execution via **`mlir-cpu-runner`**. We'll
JIT-execute the LLVM-dialect output you just produced and watch the
printf actually fire. Few new MLIR concepts — mostly toolchain glue.
