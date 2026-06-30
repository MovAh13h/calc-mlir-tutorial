#ifndef CALC_PATTERNS_TD
#define CALC_PATTERNS_TD

include "mlir/IR/PatternBase.td"
include "CalcDialect.td"

// =============================================================================
// Declarative Rewrite Rules (DRR).
//
// Each `def NAME : Pat<(source-pattern), (result-pattern)>` declares a
// rewrite. mlir-tblgen -gen-rewriters compiles them to C++ classes
// named NAME, which we add to the canonicalizer in CalcDialect.cpp
// via patterns.add<NAME>(context).
//
// In source patterns:
//   $name        — bind operand or result to a symbol
//   $name:value  — bind both the value AND the defining op
//   ConstantAttr<Attr, "val"> — match an attribute equal to "val"
//
// In result patterns:
//   (replaceWithValue $x)  — replace match with the bound SSA value $x
//
// Commutative trait (stage 03) already normalises constants to the
// RHS of add/mul, so we only need to match the `(op $x, (const c))`
// form, not the symmetric `(op (const c), $x)`.
// =============================================================================

// x + 0  →  x
def AddZero
    : Pat<(Calc_AddOp $x, (Calc_ConstOp ConstantAttr<I32Attr, "0">)),
          (replaceWithValue $x)>;

// x * 1  →  x
def MulOne
    : Pat<(Calc_MulOp $x, (Calc_ConstOp ConstantAttr<I32Attr, "1">)),
          (replaceWithValue $x)>;

// x * 0  →  0   (note: we replace with the *zero constant*, not x)
def MulZero
    : Pat<(Calc_MulOp $x,
                      (Calc_ConstOp:$zero ConstantAttr<I32Attr, "0">)),
          (replaceWithValue $zero)>;

#endif // CALC_PATTERNS_TD
