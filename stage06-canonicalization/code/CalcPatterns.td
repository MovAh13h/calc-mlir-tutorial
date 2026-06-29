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

// =============================================================================
// TASK 1: write three DRR patterns. Each pattern is a single
// `def NAME : Pat<(source), (result)>` record.
//
// The names MUST be exactly `AddZero`, `MulOne`, `MulZero` — they're
// referenced by these names in CalcDialect.cpp (see task 3).
//
//   AddZero:  match (calc.add $x, (calc.const 0)) and replace with $x
//   MulOne:   match (calc.mul $x, (calc.const 1)) and replace with $x
//   MulZero:  match (calc.mul $x, (calc.const 0)) and replace with the
//             zero constant (not with $x!)
//
// Syntax cheat sheet:
//
//     ConstantAttr<I32Attr, "0">     // match an I32Attr with value 0
//     (Calc_AddOp $x, $y)            // match a calc.add binding operands
//     (Calc_ConstOp:$z ...)          // bind both the value AND the op
//     (replaceWithValue $x)          // result: replace the matched DAG
//                                    // with the SSA value $x
// =============================================================================

// TODO: write AddZero, MulOne, MulZero here.

#endif // CALC_PATTERNS_TD
