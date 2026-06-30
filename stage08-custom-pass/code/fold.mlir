// Constant-folding tests. Run with --canonicalize so that fold()
// methods are invoked.

// 3 + 4 → 7
// CHECK-LABEL: func.func @fold_add
// CHECK-NOT:     calc.add
// CHECK:         %[[C:.*]] = calc.const 7 : i32
// CHECK:         return %[[C]] : i32
func.func @fold_add() -> i32 {
  %a = calc.const 3 : i32
  %b = calc.const 4 : i32
  %r = calc.add %a, %b : i32
  return %r : i32
}

// 6 * 7 → 42
// CHECK-LABEL: func.func @fold_mul
// CHECK-NOT:     calc.mul
// CHECK:         %[[C:.*]] = calc.const 42 : i32
// CHECK:         return %[[C]] : i32
func.func @fold_mul() -> i32 {
  %a = calc.const 6 : i32
  %b = calc.const 7 : i32
  %r = calc.mul %a, %b : i32
  return %r : i32
}

// (1 + 2) * (3 + 4) → 21  — chained folds across multiple ops.
// CHECK-LABEL: func.func @fold_chain
// CHECK-NOT:     calc.add
// CHECK-NOT:     calc.mul
// CHECK:         %[[C:.*]] = calc.const 21 : i32
// CHECK:         return %[[C]] : i32
func.func @fold_chain() -> i32 {
  %a = calc.const 1 : i32
  %b = calc.const 2 : i32
  %c = calc.const 3 : i32
  %d = calc.const 4 : i32
  %s1 = calc.add %a, %b : i32
  %s2 = calc.add %c, %d : i32
  %r = calc.mul %s1, %s2 : i32
  return %r : i32
}

// Mixed: only one operand constant — must NOT fold.
// CHECK-LABEL: func.func @no_fold_one_dynamic
// CHECK:         %[[C:.*]] = calc.const 5 : i32
// CHECK:         %[[R:.*]] = calc.add %arg0, %[[C]] : i32
// CHECK:         return %[[R]] : i32
func.func @no_fold_one_dynamic(%x: i32) -> i32 {
  %c = calc.const 5 : i32
  %r = calc.add %x, %c : i32
  return %r : i32
}

// Folded result printed via calc.print — the const survives because
// it has a real use (the print).
// CHECK-LABEL: func.func @fold_then_print
// CHECK-NOT:     calc.add
// CHECK:         %[[C:.*]] = calc.const 10 : i32
// CHECK:         calc.print %[[C]] : i32
// CHECK:         return
func.func @fold_then_print() {
  %a = calc.const 4 : i32
  %b = calc.const 6 : i32
  %s = calc.add %a, %b : i32
  calc.print %s : i32
  return
}
