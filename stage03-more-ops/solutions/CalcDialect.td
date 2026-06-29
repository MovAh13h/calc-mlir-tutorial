#ifndef CALC_DIALECT_TD
#define CALC_DIALECT_TD

include "mlir/IR/OpBase.td"
include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// -----------------------------------------------------------------------------
// Dialect (from stage 01).
// -----------------------------------------------------------------------------
def Calc_Dialect : Dialect {
  let name = "calc";
  let summary = "A tutorial dialect for arithmetic over i32.";
  let cppNamespace = "::mlir::calc";
}

class Calc_Op<string mnemonic, list<Trait> traits = []>
    : Op<Calc_Dialect, mnemonic, traits>;

// -----------------------------------------------------------------------------
// calc.const (from stage 02).
//
//     %x = calc.const 42 : i32
// -----------------------------------------------------------------------------
def Calc_ConstOp : Calc_Op<"const", [Pure]> {
  let summary = "Produce a 32-bit integer constant.";
  let arguments = (ins I32Attr:$value);
  let results = (outs I32:$result);
  let assemblyFormat = "$value attr-dict `:` type($result)";
}

// -----------------------------------------------------------------------------
// calc.add — integer addition.
//
//     %s = calc.add %a, %b : i32
//
// Traits explained:
//   - Pure: no side effects (safe to DCE / CSE / hoist).
//   - Commutative: %a + %b == %b + %a. Canonicalization uses this to
//     put operands in a canonical order, which makes other patterns
//     simpler to write.
//   - SameOperandsAndResultType: verifier enforces all three (lhs,
//     rhs, result) have the same type. Plus, the assembly format can
//     print/parse just ONE type and the others are inferred.
// -----------------------------------------------------------------------------
def Calc_AddOp : Calc_Op<"add",
    [Pure, Commutative, SameOperandsAndResultType]> {
  let summary = "Integer addition.";
  let arguments = (ins I32:$lhs, I32:$rhs);
  let results = (outs I32:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}

// -----------------------------------------------------------------------------
// calc.mul — integer multiplication.
//
//     %p = calc.mul %a, %b : i32
//
// Same shape as calc.add — including Commutative, since integer
// multiplication is commutative.
// -----------------------------------------------------------------------------
def Calc_MulOp : Calc_Op<"mul",
    [Pure, Commutative, SameOperandsAndResultType]> {
  let summary = "Integer multiplication.";
  let arguments = (ins I32:$lhs, I32:$rhs);
  let results = (outs I32:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}

#endif // CALC_DIALECT_TD
