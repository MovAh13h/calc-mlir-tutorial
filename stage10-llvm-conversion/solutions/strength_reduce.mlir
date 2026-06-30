// Run with --calc-strength-reduce.

// mul x, 2 → add x, x.
// CHECK-LABEL: func.func @mul_by_two
// CHECK-SAME:    (%[[X:.*]]: i32)
// CHECK-NOT:     calc.mul
// CHECK-NOT:     calc.const
// CHECK:         %[[R:.*]] = calc.add %[[X]], %[[X]] : i32
// CHECK:         return %[[R]] : i32
func.func @mul_by_two(%x: i32) -> i32 {
  %c2 = calc.const 2 : i32
  %r = calc.mul %x, %c2 : i32
  return %r : i32
}

// Commutativity: constant on the LHS also works, because the
// Commutative trait makes the canonicalizer normalise constants to
// the RHS before the pattern sees the op. (The greedy driver folds
// alongside patterns.)
// CHECK-LABEL: func.func @mul_two_by_x
// CHECK-SAME:    (%[[X:.*]]: i32)
// CHECK-NOT:     calc.mul
// CHECK:         %[[R:.*]] = calc.add %[[X]], %[[X]] : i32
// CHECK:         return %[[R]] : i32
func.func @mul_two_by_x(%x: i32) -> i32 {
  %c2 = calc.const 2 : i32
  %r = calc.mul %c2, %x : i32
  return %r : i32
}

// mul x, 3 — pattern must NOT fire.
// CHECK-LABEL: func.func @mul_by_three
// CHECK:         %[[C:.*]] = calc.const 3 : i32
// CHECK:         %[[R:.*]] = calc.mul %arg0, %[[C]] : i32
// CHECK:         return %[[R]] : i32
func.func @mul_by_three(%x: i32) -> i32 {
  %c3 = calc.const 3 : i32
  %r = calc.mul %x, %c3 : i32
  return %r : i32
}

// mul x, y where neither is constant — pattern must NOT fire.
// CHECK-LABEL: func.func @mul_dynamic
// CHECK:         calc.mul %arg0, %arg1 : i32
func.func @mul_dynamic(%x: i32, %y: i32) -> i32 {
  %r = calc.mul %x, %y : i32
  return %r : i32
}
