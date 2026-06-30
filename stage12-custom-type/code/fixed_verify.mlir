// Negative tests for FixedType::verify.
// Run with --verify-diagnostics --split-input-file.

// expected-error @+1 {{fixed-point type must have at least 1 fractional bit}}
func.func @no_frac_bits(%a: !calc.fixed<8, 0>) -> !calc.fixed<8, 0> {
  return %a : !calc.fixed<8, 0>
}

// -----

// expected-error @+1 {{intBits + fracBits must be 8, 16, 32, or 64}}
func.func @weird_width(%a: !calc.fixed<5, 5>) -> !calc.fixed<5, 5> {
  return %a : !calc.fixed<5, 5>
}

// -----

// expected-error @+1 {{intBits + fracBits must be 8, 16, 32, or 64}}
func.func @too_wide(%a: !calc.fixed<64, 64>) -> !calc.fixed<64, 64> {
  return %a : !calc.fixed<64, 64>
}
