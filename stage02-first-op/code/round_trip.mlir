// Round-trip test: parse this file with calc-opt, print it back, and
// FileCheck the output against the CHECK lines.

// CHECK-LABEL: func.func @forty_two
// CHECK-SAME:    () -> i32
// CHECK:         %[[C:.*]] = calc.const 42 : i32
// CHECK:         return %[[C]] : i32
func.func @forty_two() -> i32 {
  %x = calc.const 42 : i32
  return %x : i32
}

// CHECK-LABEL: func.func @two_constants
// CHECK:         %{{.*}} = calc.const 1 : i32
// CHECK:         %{{.*}} = calc.const 2 : i32
func.func @two_constants() {
  %a = calc.const 1 : i32
  %b = calc.const 2 : i32
  return
}
