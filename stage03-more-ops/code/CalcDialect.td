#ifndef CALC_DIALECT_TD
#define CALC_DIALECT_TD

include "mlir/IR/OpBase.td"
include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// -----------------------------------------------------------------------------
// Dialect + helper base class (unchanged from stage 02).
// -----------------------------------------------------------------------------
def Calc_Dialect : Dialect {
  let name = "calc";
  let summary = "A tutorial dialect for arithmetic over i32.";
  let cppNamespace = "::mlir::calc";
}

class Calc_Op<string mnemonic, list<Trait> traits = []>
    : Op<Calc_Dialect, mnemonic, traits>;

// -----------------------------------------------------------------------------
// calc.const (from stage 02, kept).
// -----------------------------------------------------------------------------
def Calc_ConstOp : Calc_Op<"const", [Pure]> {
  let summary = "Produce a 32-bit integer constant.";
  let arguments = (ins I32Attr:$value);
  let results = (outs I32:$result);
  let assemblyFormat = "$value attr-dict `:` type($result)";
}

// =============================================================================
// TASK 1: define `calc.add`.
//
// Target IR:
//
//     %s = calc.add %a, %b : i32
//
// Traits to use:
//   - Pure                          : no side effects
//   - Commutative                   : a+b == b+a (canonicalizer uses this)
//   - SameOperandsAndResultType     : verifier enforces all three types
//                                     are equal, AND lets the assembly
//                                     format print just one type
//
// Arguments:  (ins I32:$lhs, I32:$rhs)
// Results:    (outs I32:$result)
// Format:     "$lhs `,` $rhs attr-dict `:` type($result)"
// =============================================================================

// TODO: write `def Calc_AddOp : Calc_Op<"add", [...]> { ... }` here.


// =============================================================================
// TASK 2: define `calc.mul`.
//
// Target IR:
//
//     %p = calc.mul %a, %b : i32
//
// Same shape as calc.add — including Commutative, since integer
// multiplication is commutative. The only difference is the mnemonic
// (`"mul"`) and the summary.
// =============================================================================

// TODO: write `def Calc_MulOp : Calc_Op<"mul", [...]> { ... }` here.

#endif // CALC_DIALECT_TD
