# Stage 04 — Side effects: `calc.print`

## What you'll learn

- What **memory effects** are in MLIR and why they matter
- How `Pure` is dangerous for IO-producing ops
- How `MemoryEffects<[MemWrite]>` keeps an op alive through DCE
- That ops can have **no results** — they exist for side effects alone

By the end you'll have `calc.print`, the first non-`Pure` op in our
dialect. It doesn't actually print anything yet (we'll lower it to
`printf` in stage 10/11) — for now it just survives passes that would
delete `Pure` ops.

## Background

### The problem with `Pure`

Every op so far has been `Pure`. That trait promises MLIR three things:

1. No reads, no writes, no allocations — the op is mathematically pure.
2. Safe to **speculatively execute** (run on paths where the result
   isn't needed).
3. Safe to **delete** if the result has no users.

For `calc.const`, `calc.add`, `calc.mul` these promises hold. For an
op that prints to stdout, they emphatically don't:

```mlir
%x = calc.const 42 : i32
calc.print %x : i32         // imagine this had Pure...
return
```

If `calc.print` were `Pure`, the canonicalizer would notice the op has
no result (so trivially "no users") and delete it. Your print
disappears. Bad.

### Memory effects, briefly

MLIR's side-effect framework lets ops declare which **resources** they
read, write, or allocate, on which **kinds** of memory. Resources can
be specific (e.g., a particular buffer), but most ops use
`DefaultResource` — "some part of the world I'd rather not specify."

The effect classes are:

| Effect | Meaning |
|---|---|
| `MemRead` | reads from a resource |
| `MemWrite` | writes to a resource (e.g., stdout, memory) |
| `MemAlloc` | allocates a resource |
| `MemFree` | frees a resource |

`calc.print` writes to stdout, so it gets `MemWrite`. With this trait,
DCE looks at the op, sees "this op writes somewhere observable," and
leaves it alone.

### The ODS syntax

```td
def Calc_PrintOp : Calc_Op<"print", [MemoryEffects<[MemWrite]>]> {
  let summary = "Print an i32 to stdout (lowered to printf later).";
  let arguments = (ins I32:$value);
  // (no `let results = ...` — no results)
  let assemblyFormat = "$value attr-dict `:` type($value)";
}
```

`MemoryEffects<[...]>` is parameterized by a list of effect specs.
Bare `MemWrite` is shorthand for `MemWrite<DefaultResource>` — write
to the catch-all resource.

### Ops with no results

`let results = (outs ...)` is just an `outs` list. If you have nothing
to put in it, **omit the whole field**. ODS handles zero-result ops
without complaint. In IR, you write:

```mlir
calc.print %x : i32        // no `%y = ` because there's nothing to bind
```

### What the optimizer can still do

`MemWrite` doesn't make the op immortal — it just protects against
*delete-because-no-users*. The optimizer might still:

- **Reorder** unrelated `Pure` ops around your print
- **CSE-merge** two prints with the same operand (only if it can prove
  they're equivalent; usually it can't and won't)
- **Hoist** the print out of a loop if it always prints the same value
  (rare)

For most purposes, `MemWrite` does the right thing. If you needed
stricter ordering, you'd write a more specific resource type — but
that's well beyond this tutorial.

## Glossary (new this stage)

- **Memory effect** — declared behavior of an op with respect to some
  memory resource.
- **Resource** — abstract "thing in the world" an op may touch.
  `DefaultResource` is the catch-all.
- **`MemRead` / `MemWrite` / `MemAlloc` / `MemFree`** — the four
  effect kinds.
- **DCE (dead code elimination)** — pass (run by `--canonicalize`)
  that removes ops whose results are unused, *unless* the op has
  observable side effects.
- **`MemoryEffects<[...]>` trait** — ODS shorthand for declaring an
  op's effect list.

## Tasks

One file to edit: `code/CalcDialect.td`. Add `Calc_PrintOp`.

### Task 1 — define `calc.print`

See the TODO comment in `code/CalcDialect.td`. The op has:

- mnemonic `"print"`
- one operand `I32:$value`
- no results
- traits `[MemoryEffects<[MemWrite]>]`
- assembly format `"$value attr-dict ` `:` ` type($value)"`

## Running the tests

```bash
bazel test //stage04-side-effects/code/...
```

There are two tests:

1. `round_trip_test` — parses and re-prints a file with `calc.print`.
2. `dce_test` — runs `--canonicalize` on a function with both a dead
   `calc.add` and a live `calc.print`, and verifies the add is
   removed while the print survives.

The second test is the interesting one: it fails if you add `Pure` to
`calc.print`, because the canonicalizer deletes the print along with
the dead add.

You can experiment:

```bash
bazel run //stage04-side-effects/code:calc-opt -- \
    --canonicalize \
    "$PWD/stage04-side-effects/code/dce.mlir"
```

## Common mistakes

### `Variable not defined: 'MemoryEffects'`

You forgot `include "mlir/Interfaces/SideEffectInterfaces.td"` at the
top of the `.td`. (Stage's boilerplate has it.)

### Test fails: `calc.print` was deleted

You added `Pure` (or no traits, in some configurations). Use
`MemoryEffects<[MemWrite]>` and only that — at minimum, do not add
`Pure`.

### Test fails: `error: expected ':'`

Your assembly format mismatches what the test file writes. The standard
shape for a one-operand op with a typed operand is:

```td
let assemblyFormat = "$value attr-dict `:` type($value)";
```

Note: `type($value)`, not `type($result)` — there *is* no result.

## Try this

Make a small file that prints a computed value, then run it through
several passes:

```bash
cat > /tmp/p.mlir <<'EOF'
func.func @main() {
  %x = calc.const 6 : i32
  %y = calc.const 7 : i32
  %z = calc.mul %x, %y : i32
  calc.print %z : i32
  return
}
EOF

# Plain round-trip
bazel run //stage04-side-effects/code:calc-opt -- /tmp/p.mlir

# With canonicalization (the mul stays because z is used; print stays
# because it has MemWrite)
bazel run //stage04-side-effects/code:calc-opt -- --canonicalize /tmp/p.mlir
```

If you change `calc.print %z : i32` to remove the `%z` usage entirely,
canonicalize will then DCE the unused `mul` but still keep the print.

## Next stage

→ Stage 05: custom verifiers — when traits don't capture the rule.
