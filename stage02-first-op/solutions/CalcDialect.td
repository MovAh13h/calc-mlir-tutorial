#ifndef CALC_DIALECT_TD
#define CALC_DIALECT_TD

include "mlir/IR/OpBase.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// -----------------------------------------------------------------------------
// The dialect (from stage 01, unchanged).
// -----------------------------------------------------------------------------
def Calc_Dialect : Dialect {
  let name = "calc";
  let summary = "A tutorial dialect for arithmetic over i32.";
  let cppNamespace = "::mlir::calc";
}

// -----------------------------------------------------------------------------
// Convenience base class so every op definition doesn't have to repeat the
// dialect reference.
// -----------------------------------------------------------------------------
class Calc_Op<string mnemonic, list<Trait> traits = []>
    : Op<Calc_Dialect, mnemonic, traits>;

// -----------------------------------------------------------------------------
// calc.const — an i32 constant.
//
//     %x = calc.const 42 : i32
//
// Traits:
//   - Pure: no side effects, can be CSE'd, dead-code-eliminated.
//
// Arguments / results:
//   - $value: an I32Attr (signless 32-bit integer attribute) holding
//             the constant value.
//   - $result: the produced SSA value, constrained to i32.
//
// Assembly format:
//   "$value attr-dict `:` type($result)"  produces e.g.
//     calc.const 42 : i32
//   ($value prints just the integer literal; the trailing `:` and
//   type($result) print the result type explicitly, matching the
//   convention used by arith.constant.)
// -----------------------------------------------------------------------------
def Calc_ConstOp : Calc_Op<"const", [Pure]> {
  let summary = "Produce a 32-bit integer constant.";
  let arguments = (ins I32Attr:$value);
  let results = (outs I32:$result);
  let assemblyFormat = "$value attr-dict `:` type($result)";
}

#endif // CALC_DIALECT_TD
