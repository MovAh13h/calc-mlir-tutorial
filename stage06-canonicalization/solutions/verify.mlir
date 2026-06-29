// Negative tests for calc.shr's verifier. Run with --verify-diagnostics:
// MLIR walks the input, checks every `// expected-error` comment fires
// at the right place, and reports failure if any expected diagnostic
// is missing or unexpected diagnostics appear.

// Each snippet below is separated by a line with the split marker.

// Bad: shift amount 32 (just out of range).
func.func @bad_shift_32(%x: i32) -> i32 {
  %c = calc.const 32 : i32
  // expected-error @+1 {{shift amount must be in [0, 31], got 32}}
  %r = calc.shr %x, %c : i32
  return %r : i32
}

// -----

// Bad: shift amount 100.
func.func @bad_shift_100(%x: i32) -> i32 {
  %c = calc.const 100 : i32
  // expected-error @+1 {{shift amount must be in [0, 31], got 100}}
  %r = calc.shr %x, %c : i32
  return %r : i32
}

// -----

// Good (boundary): shift amount 31 is fine.
func.func @good_shift_31(%x: i32) -> i32 {
  %c = calc.const 31 : i32
  %r = calc.shr %x, %c : i32
  return %r : i32
}

// -----

// Good: dynamic shift amount — verifier can't check, so it accepts.
func.func @good_dynamic_shift(%x: i32, %amt: i32) -> i32 {
  %r = calc.shr %x, %amt : i32
  return %r : i32
}
