# Stage 11 — End-to-end execution via `mlir-cpu-runner`

## What you'll learn

- What **`mlir-cpu-runner`** does — JIT-compile LLVM-dialect MLIR and
  run it as a native function
- How `printf` lands on real stdout via the host's libc
- Plumbing a test that checks against a *running program's output*,
  not the IR
- The roles of `-e main` and `--entry-point-result=void`

By the end, `bazel test //stage11-jit-execution/code:jit_test` will:
1. Lower `jit.mlir` from calc → arith → LLVM dialect (using the
   passes you built in stages 09–10).
2. Feed the result to `mlir-cpu-runner`.
3. JIT-compile and execute `@main`, which calls `printf` for real.
4. Pipe the program's stdout to `FileCheck` and verify it matches
   your `// CHECK` directives.

The big psychological shift: by stage 10 we'd produced "IR that
*looks* like it would print 42." This stage actually prints 42.

## Background

### What `mlir-cpu-runner` is

A standalone tool from the MLIR distribution that:
- Parses an LLVM-dialect MLIR file (no calc, no arith — pure LLVM).
- Translates it to LLVM IR (in memory, via the same machinery as
  `mlir-translate --mlir-to-llvmir`).
- Hands it to LLVM's ORC JIT.
- Invokes a designated entry-point function from C++.

Because the JIT loads into the host process, the program can call
into anything dynamically resolvable — including libc functions like
`printf`. We rely on that here: our `calc.print` lowering emitted
`llvm.call @printf`, and the JIT links that against the host libc.

Flags we use:
- `-e main` — the entry-point function name.
- `--entry-point-result=void` — the entry-point returns `void`. (Other
  options: `i32`, `f32`.)

### Why our pipeline works as-is

We don't have to write any new C++ for stage 11. Stages 09–10 already
built every pass; this stage just chains them and pipes through the
JIT. The pipeline produces:

```
module attributes {llvm.data_layout = ""} {
  llvm.mlir.global internal constant @calc_print_fmt("%d\n\00")
  llvm.func @printf(!llvm.ptr, ...) -> i32
  llvm.func @main() {
    ...
    llvm.call @printf(%fmt, %v) : (!llvm.ptr, i32) -> i32
    ...
    llvm.return
  }
}
```

…and that's pure LLVM dialect. `mlir-cpu-runner` will happily take it.

### Why testing stdout is different

Previously, our FileCheck tests matched against MLIR's textual
*output IR* (the result of running passes). Here, we match against
the *program's stdout* (what gets printed when main runs). The CHECK
directives still live in the source file, but they describe runtime
output rather than IR shape.

`run_jit.sh` does:
```bash
calc-opt [pipeline] input.mlir |     # → LLVM dialect IR
  mlir-cpu-runner -e main             # → JIT compile + execute
                  --entry-point-result=void |
  FileCheck input.mlir                # match against // CHECK lines
```

The pipe takes program stdout (printfs) into FileCheck. Compile-time
diagnostics from calc-opt would go to stderr and not reach FileCheck.

## Glossary (new this stage)

- **`mlir-cpu-runner`** — MLIR's built-in JIT host. Parses LLVM-dialect
  MLIR, lowers to LLVM IR, ORC-JITs it, calls a designated entry-point.
- **JIT (just-in-time compilation)** — translating code to machine
  code at runtime instead of ahead of time.
- **ORC** — LLVM's modern JIT engine (On-Request Compilation).
- **Entry-point** — the function the runner invokes after JITing.
  Selected with `-e <name>`.
- **`--entry-point-result=void/i32/f32`** — declares the return type
  of the entry-point so the runner knows how to invoke it (and whether
  to print the return value).

## Tasks

There's only one task — write the `// CHECK` lines.

### Task 1 — fill in expected output in `code/jit.mlir`

`jit.mlir` already has a `@main` function with three `calc.print`
calls (2, 7, 42). Add `// CHECK` directives describing the expected
program output.

Tip: the format string emitted by `calc.print` is `"%d\n"`, so each
print produces one line containing the integer.

If you'd rather see the output first, run the pipeline interactively:

```bash
bazel build //stage11-jit-execution/code:calc-opt @llvm-project//mlir:mlir-cpu-runner
bazel-bin/stage11-jit-execution/code/calc-opt \
    --calc-to-arith --calc-print-to-llvm \
    --convert-arith-to-llvm --convert-func-to-llvm \
    --reconcile-unrealized-casts \
    stage11-jit-execution/code/jit.mlir |
bazel-bin/external/llvm-project+/mlir/mlir-cpu-runner \
    -e main --entry-point-result=void
```

Whatever comes out is what your CHECK directives should match.

## Running the tests

```bash
bazel test //stage11-jit-execution/code/...
```

`jit_test` is the new one; all carryovers from stage 10 still apply.

## Common mistakes

### "expected string not found in input"

Your CHECK doesn't match the actual stdout. Run the pipeline
interactively (see above) and compare line by line.

### "could not parse the input IR"

calc-opt's pipeline didn't fully lower to LLVM dialect — there's still
a `calc.*` or `func.*` op in the output that `mlir-cpu-runner` can't
handle. Inspect the IR by running calc-opt without the JIT pipe:

```bash
bazel-bin/stage11-jit-execution/code/calc-opt \
    --calc-to-arith --calc-print-to-llvm \
    --convert-arith-to-llvm --convert-func-to-llvm \
    --reconcile-unrealized-casts \
    stage11-jit-execution/code/jit.mlir
```

Anything that isn't `llvm.*` is suspect.

### "JIT session error: Symbols not found: { printf }"

The host libc isn't being resolved. Usually a platform/toolchain
issue — on macOS and Linux this works out of the box; on more exotic
setups you'd need `--shared-libs=` to point to libc explicitly. Not
expected to happen here.

### Test passes locally but the printed numbers look wrong

You probably have stale cached test results from before you edited
`jit.mlir`. `bazel test --cache_test_results=no //stage11-...:jit_test`
to force a re-run.

## Try this

1. Change `@main` to read its inputs from environment variables (no,
   you can't — there are no entry-point args from the runner). Use
   different constants instead and confirm the output changes.
2. Add a `--canonicalize` step to the pipeline *before*
   `--calc-to-arith`. The folder collapses `3+4` and `6*7` to
   constants; verify the program still prints the same numbers.
3. Make `@main` return `i32` (the exit code). You'll need to switch
   the test's `--entry-point-result=void` to `--entry-point-result=i32`.

## Next stage

→ Stage 12 (optional capstone): add a **custom type** —
`!calc.fixed<int_bits, frac_bits>`, a fixed-point representation
with parameters. You'll learn how ODS handles types (vs. ops) and how
custom assembly format works for type literals.
