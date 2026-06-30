// Round-trip the parameterised type and the ops that use it.
//
// Note: MLIR's printer elides the `!calc.` prefix on the type when
// it appears as the trailing type of an op result (`: <8, 8>`),
// because the operand position already implies "an op result". In
// function signatures the full `!calc.fixed<8, 8>` form is required.

// CHECK-LABEL: func.func @fixed_q8_8
// CHECK-SAME:    (%[[A:.*]]: !calc.fixed<8, 8>)
// CHECK-SAME:    -> !calc.fixed<8, 8>
// CHECK:         %[[C:.*]] = calc.fconst 256 : <8, 8>
// CHECK:         %[[R:.*]] = calc.fadd %[[A]], %[[C]] : <8, 8>
// CHECK:         return %[[R]] : !calc.fixed<8, 8>
func.func @fixed_q8_8(%a: !calc.fixed<8, 8>) -> !calc.fixed<8, 8> {
  %one = calc.fconst 256 : !calc.fixed<8, 8>     // 1.0 in Q8.8
  %r = calc.fadd %a, %one : !calc.fixed<8, 8>
  return %r : !calc.fixed<8, 8>
}

// Q4.4 — a different parameterisation; should parse identically.
// CHECK-LABEL: func.func @fixed_q4_4
// CHECK-SAME:    (%[[A:.*]]: !calc.fixed<4, 4>)
// CHECK:         %[[C:.*]] = calc.fconst 16 : <4, 4>
// CHECK:         %[[R:.*]] = calc.fadd %[[A]], %[[C]] : <4, 4>
func.func @fixed_q4_4(%a: !calc.fixed<4, 4>) -> !calc.fixed<4, 4> {
  %one = calc.fconst 16 : !calc.fixed<4, 4>      // 1.0 in Q4.4
  %r = calc.fadd %a, %one : !calc.fixed<4, 4>
  return %r : !calc.fixed<4, 4>
}

// Q16.16 — 32 bits total.
// CHECK-LABEL: func.func @fixed_q16_16
// CHECK:         calc.fconst 65536 : <16, 16>
func.func @fixed_q16_16() -> !calc.fixed<16, 16> {
  %one = calc.fconst 65536 : !calc.fixed<16, 16>
  return %one : !calc.fixed<16, 16>
}
