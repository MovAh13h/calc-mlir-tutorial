# Stage 05 — Custom verifiers

## What you'll learn

- When traits aren't enough, and you have to write a verifier by hand
- How `hasVerifier = 1` and the `verify()` C++ method fit together
- The pattern "if my operand is a constant, check something about it"
- How to test verifier errors with `--verify-diagnostics` and
  `// expected-error` directives

By the end you'll have `calc.shr` (logical shift right) with a custom
rule: if the shift amount is a known constant, it must be in `[0, 31]`.

## Background

### Traits give you verification for free — until they don't

We've already seen `SameOperandsAndResultType`, which contributes a
check to the op's `verify()` method automatically (matching operand
and result types). That's great for rules that can be **expressed as
a generic constraint**.

But many useful rules involve looking at the *values* of operands or
attributes, walking back to defining ops, or checking relationships
between things. Those are written in C++.

### The `hasVerifier` switch

Add this to your op's ODS:

```td
let hasVerifier = 1;
```

The generated C++ class now has:

```cpp
LogicalResult ShrOp::verify();
```

…declared but **not defined**. You implement it in your `.cpp`. If
you forget, you get a linker error — not the friendliest signal, but
it does stop you from shipping a half-broken op.

### The shape of a `verify()` method

```cpp
LogicalResult ShrOp::verify() {
  // ...checks...
  if (somethingBad)
    return emitOpError("description of what's wrong");
  return success();
}
```

Key APIs:

| Symbol | What it does |
|---|---|
| `LogicalResult` | success/failure return type. Use `success()` / `failure()` to construct. |
| `emitOpError(msg)` | emits a diagnostic with the op's name and location, returns a `Diagnostic` you can stream more into; the return implicitly converts to `failure()`. |
| `getOperand()`, `getAmount()`, `getValue()`, ... | auto-generated accessors from ODS names. |
| `.getDefiningOp<MyOp>()` | given an SSA `Value`, returns the `MyOp` that produced it (or null). |

### The "is this operand a known constant?" pattern

You'll see this constantly in verifiers, folders, and patterns:

```cpp
auto cst = getAmount().getDefiningOp<ConstOp>();
if (!cst) return success();   // dynamic — bail out
uint32_t v = cst.getValue();
// ...check v...
```

`getDefiningOp<ConstOp>()` does two things in one: it looks back at
the op that defines this operand, and casts it to `ConstOp` (returning
null if the op is something else). Combined with the early `return
success()`, this is the standard "check statically if you can,
otherwise accept" idiom.

### Testing verifier errors: `--verify-diagnostics`

Positive tests are easy — write valid IR, FileCheck the output. But
how do you *test that an error is correctly emitted*?

`mlir-opt --verify-diagnostics` walks the input looking for these
directives:

| Directive | Meaning |
|---|---|
| `// expected-error @+N {{msg}}` | the next + N-th line must produce an error containing `msg` |
| `// expected-warning {{...}}` | same, for warnings |
| `// expected-remark {{...}}` | same, for remarks |
| `// expected-note {{...}}` | same, for notes |

`@+1` (most common) means "the line immediately after this comment."
You can also use `@-1`, `@above`, `@below`. The text in `{{...}}` is
matched as substring, not regex.

`mlir-opt --verify-diagnostics`:
- Exits 0 if every expected diagnostic was emitted AND no unexpected
  ones leaked
- Exits nonzero if anything's missing or unexpected

Combined with `--split-input-file` (snippets separated by `// -----`),
one `.mlir` file can hold many independent test cases. We added a
`mlir_verify_diagnostics_test` macro in `common/test.bzl` for this.

## Glossary (new this stage)

- **`hasVerifier = 1`** — ODS flag asking the generator to declare a
  `verify()` method on your op; you implement it in C++.
- **`emitOpError(...)`** — produce a diagnostic anchored at this op;
  implicitly produces `failure()`.
- **`getDefiningOp<T>()`** — walk back from an SSA value to the op
  that defined it, casting to `T` (or returning null).
- **`--verify-diagnostics`** — MLIR mode that checks
  `// expected-error/warning/remark/note` directives against actual
  emitted diagnostics.
- **`--split-input-file`** — split one `.mlir` into independent
  snippets separated by `// -----` for parallel testing.

## Tasks

Two files to edit: `code/CalcDialect.td` (declare the op) and
`code/CalcDialect.cpp` (implement `verify()`).

### Task 1 — declare `calc.shr` in ODS

See the TODO in `code/CalcDialect.td`. The op:

- mnemonic `"shr"`
- traits `[Pure, SameOperandsAndResultType]`
- arguments `(ins I32:$value, I32:$amount)`
- results `(outs I32:$result)`
- assembly format `"$value ` `,` ` $amount attr-dict ` `:` ` type($result)"`
- `let hasVerifier = 1;`

### Task 2 — implement `ShrOp::verify()`

See the TODO in `code/CalcDialect.cpp`. Implement:

- If `getAmount()` is defined by a `ConstOp`, fetch the
  `uint32_t` value and reject `v > 31` with the exact message:

      shift amount must be in [0, 31], got <N>

- Otherwise return `success()`.

## Running the tests

```bash
bazel test //stage05-verifiers/code/...
```

Three tests:

| Test | Checks |
|---|---|
| `round_trip_test` | `calc.shr` parses and prints (positive) |
| `dce_test` | `calc.print` survives DCE (regression of stage 04) |
| `verify_test` | bad `calc.shr` produces the expected diagnostic |

`verify_test` uses `--verify-diagnostics`; failure messages look like:

```
expected error "shift amount must be in [0, 31], got 32" was not produced
```

…which means the verifier didn't fire on the bad case.

Or:

```
unexpected error: ...
```

…which means an error fired that no `// expected-error` covered.

## Common mistakes

### Linker error: undefined symbol `ShrOp::verify()`

You set `hasVerifier = 1` in ODS but forgot to implement the method
in C++. Add the definition to `CalcDialect.cpp`.

### Test fails: `expected error "..." was not produced`

Either:
- Your `verify()` returns `success()` when it shouldn't, OR
- The error string you pass to `emitOpError` doesn't *contain* the
  text in `{{...}}`. The directive matches as substring; spelling,
  punctuation, and the value's textual form all matter. Compare:
  ```
  "shift amount must be in [0, 31], got " << v
  ```
  vs the expected `{{shift amount must be in [0, 31], got 32}}`. The
  literal `[`, `]`, comma, and capitalization must all match.

### Test fails: `unexpected error: unexpected character ...`

Something in your `.mlir` triggered a parse error before the verifier
could even run. Most often: a typo in the IR, OR a comment line that
happens to look like a `// -----` split marker (the splitter sees
`// -----` anywhere on a line). Avoid embedding `// -----` in
comments.

### `error: failed to legalize operation 'calc.shr' that was explicitly marked illegal`

That's a conversion-pass error from a later stage leaking into your
output. Not relevant here — make sure you're running plain
`bazel test`, not chaining extra passes.

## Try this

Add another case to `verify.mlir` that tests `calc.const 31` is OK,
and `calc.const 0` is OK (boundary cases). Already there — verify
they still pass after your implementation.

Then try making the verifier *stricter* (e.g., disallow shift amount 0
since it's a no-op). Watch your existing `good_shift` tests break —
that's how you know the verifier is doing something.

## Next stage

→ Stage 06: canonicalization with declarative rewrite rules (DRR) —
write algebraic simplifications like `x + 0 → x` in ODS, no C++.
