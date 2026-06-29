// Round-trip test covering calc.const, calc.add, calc.mul.

// CHECK-LABEL: func.func @sum
// CHECK:         %[[A:.*]] = calc.const 1 : i32
// CHECK:         %[[B:.*]] = calc.const 2 : i32
// CHECK:         %[[S:.*]] = calc.add %[[A]], %[[B]] : i32
// CHECK:         return %[[S]] : i32
func.func @sum() -> i32 {
  %a = calc.const 1 : i32
  %b = calc.const 2 : i32
  %s = calc.add %a, %b : i32
  return %s : i32
}

// CHECK-LABEL: func.func @product
// CHECK:         %[[A:.*]] = calc.const 3 : i32
// CHECK:         %[[B:.*]] = calc.const 4 : i32
// CHECK:         %[[P:.*]] = calc.mul %[[A]], %[[B]] : i32
// CHECK:         return %[[P]] : i32
func.func @product() -> i32 {
  %a = calc.const 3 : i32
  %b = calc.const 4 : i32
  %p = calc.mul %a, %b : i32
  return %p : i32
}

// (x+1) * (x+2) — exercises composition of ops.
// CHECK-LABEL: func.func @poly
// CHECK-SAME:    (%[[X:.*]]: i32) -> i32
// CHECK:         %[[C1:.*]] = calc.const 1 : i32
// CHECK:         %[[C2:.*]] = calc.const 2 : i32
// CHECK:         %[[P1:.*]] = calc.add %[[X]], %[[C1]] : i32
// CHECK:         %[[P2:.*]] = calc.add %[[X]], %[[C2]] : i32
// CHECK:         %[[R:.*]] = calc.mul %[[P1]], %[[P2]] : i32
// CHECK:         return %[[R]] : i32
func.func @poly(%x: i32) -> i32 {
  %c1 = calc.const 1 : i32
  %c2 = calc.const 2 : i32
  %p1 = calc.add %x, %c1 : i32
  %p2 = calc.add %x, %c2 : i32
  %r = calc.mul %p1, %p2 : i32
  return %r : i32
}
