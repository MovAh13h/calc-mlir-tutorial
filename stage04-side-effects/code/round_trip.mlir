// Round-trip tests for calc.print.

// CHECK-LABEL: func.func @prints
// CHECK:         calc.print %{{.*}} : i32
// CHECK:         return
func.func @prints(%x: i32) {
  calc.print %x : i32
  return
}

// (3 + 4) printed.
// CHECK-LABEL: func.func @add_and_print
// CHECK:         %[[A:.*]] = calc.const 3 : i32
// CHECK:         %[[B:.*]] = calc.const 4 : i32
// CHECK:         %[[S:.*]] = calc.add %[[A]], %[[B]] : i32
// CHECK:         calc.print %[[S]] : i32
// CHECK:         return
func.func @add_and_print() {
  %a = calc.const 3 : i32
  %b = calc.const 4 : i32
  %s = calc.add %a, %b : i32
  calc.print %s : i32
  return
}
