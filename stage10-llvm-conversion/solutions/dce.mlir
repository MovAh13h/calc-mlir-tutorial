// Test that canonicalization preserves calc.print (side-effecting) but
// removes a dead, Pure calc.add. Run with --canonicalize.

// CHECK-LABEL: func.func @dce_preserves_print
// CHECK-NOT:     calc.add
// CHECK:         calc.print %{{.*}} : i32
// CHECK:         return
func.func @dce_preserves_print(%x: i32) {
  %dead = calc.add %x, %x : i32       // Pure + unused — DCE removes
  calc.print %x : i32                  // side-effecting — must stay
  return
}
