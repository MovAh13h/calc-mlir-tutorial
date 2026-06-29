// Tests for DRR canonicalization patterns. Run with --canonicalize.

// x + 0  →  x
// CHECK-LABEL: func.func @add_zero
// CHECK-NOT:     calc.add
// CHECK-NOT:     calc.const
// CHECK:         return %arg0 : i32
func.func @add_zero(%x: i32) -> i32 {
  %z = calc.const 0 : i32
  %r = calc.add %x, %z : i32
  return %r : i32
}

// x * 1  →  x
// CHECK-LABEL: func.func @mul_one
// CHECK-NOT:     calc.mul
// CHECK-NOT:     calc.const
// CHECK:         return %arg0 : i32
func.func @mul_one(%x: i32) -> i32 {
  %one = calc.const 1 : i32
  %r = calc.mul %x, %one : i32
  return %r : i32
}

// x * 0  →  0   (entire mul folded to a zero constant; x is irrelevant)
// CHECK-LABEL: func.func @mul_zero
// CHECK-NOT:     calc.mul
// CHECK:         %[[Z:.*]] = calc.const 0 : i32
// CHECK:         return %[[Z]] : i32
func.func @mul_zero(%x: i32) -> i32 {
  %z = calc.const 0 : i32
  %r = calc.mul %x, %z : i32
  return %r : i32
}

// Negative test: x + 7 should NOT fold (no pattern for general
// integers).
// CHECK-LABEL: func.func @add_seven
// CHECK:         %[[C:.*]] = calc.const 7 : i32
// CHECK:         %[[R:.*]] = calc.add %arg0, %[[C]] : i32
// CHECK:         return %[[R]] : i32
func.func @add_seven(%x: i32) -> i32 {
  %c = calc.const 7 : i32
  %r = calc.add %x, %c : i32
  return %r : i32
}
