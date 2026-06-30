// Run with --calc-to-arith.
//
// calc arithmetic ops are lowered to arith equivalents; calc.print
// stays in place (partial conversion). We use function arguments
// for operands to keep arith folds from collapsing the results
// into a single constant.

// CHECK-LABEL: func.func @lower_add
// CHECK-NOT:     calc.add
// CHECK:         %[[R:.*]] = arith.addi %arg0, %arg1 : i32
// CHECK:         return %[[R]] : i32
func.func @lower_add(%a: i32, %b: i32) -> i32 {
  %r = calc.add %a, %b : i32
  return %r : i32
}

// CHECK-LABEL: func.func @lower_mul
// CHECK-NOT:     calc.mul
// CHECK:         %[[R:.*]] = arith.muli %arg0, %arg1 : i32
// CHECK:         return %[[R]] : i32
func.func @lower_mul(%a: i32, %b: i32) -> i32 {
  %r = calc.mul %a, %b : i32
  return %r : i32
}

// CHECK-LABEL: func.func @lower_shr
// CHECK-NOT:     calc.shr
// CHECK:         %[[R:.*]] = arith.shrui %arg0, %arg1 : i32
// CHECK:         return %[[R]] : i32
func.func @lower_shr(%x: i32, %amt: i32) -> i32 {
  %r = calc.shr %x, %amt : i32
  return %r : i32
}

// calc.const → arith.constant — the only place we actually exercise
// the constant lowering, since the other tests don't have constants.
// CHECK-LABEL: func.func @lower_const
// CHECK-NOT:     calc.const
// CHECK:         %[[C:.*]] = arith.constant 42 : i32
// CHECK:         return %[[C]] : i32
func.func @lower_const() -> i32 {
  %c = calc.const 42 : i32
  return %c : i32
}

// Mixed: arith lowering plus the surviving calc.print.
// CHECK-LABEL: func.func @lower_mixed
// CHECK-NOT:     calc.add
// CHECK-NOT:     calc.mul
// CHECK:         %[[S:.*]] = arith.addi %arg0, %arg1 : i32
// CHECK:         %[[R:.*]] = arith.muli %[[S]], %arg2 : i32
// CHECK:         calc.print %[[R]] : i32
// CHECK:         return
func.func @lower_mixed(%x: i32, %y: i32, %z: i32) {
  %s = calc.add %x, %y : i32
  %r = calc.mul %s, %z : i32
  calc.print %r : i32
  return
}
