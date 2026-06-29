#ifndef CALC_DIALECT_TD
#define CALC_DIALECT_TD

include "mlir/IR/OpBase.td"
include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// -----------------------------------------------------------------------------
// Dialect + helper base class (unchanged).
// -----------------------------------------------------------------------------
def Calc_Dialect : Dialect {
  let name = "calc";
  let summary = "A tutorial dialect for arithmetic over i32.";
  let cppNamespace = "::mlir::calc";
}

class Calc_Op<string mnemonic, list<Trait> traits = []>
    : Op<Calc_Dialect, mnemonic, traits>;

// -----------------------------------------------------------------------------
// calc.const (unchanged).
// -----------------------------------------------------------------------------
def Calc_ConstOp : Calc_Op<"const", [Pure]> {
  let summary = "Produce a 32-bit integer constant.";
  let arguments = (ins I32Attr:$value);
  let results = (outs I32:$result);
  let assemblyFormat = "$value attr-dict `:` type($result)";
}

// -----------------------------------------------------------------------------
// calc.add / calc.mul (unchanged).
// -----------------------------------------------------------------------------
def Calc_AddOp : Calc_Op<"add",
    [Pure, Commutative, SameOperandsAndResultType]> {
  let summary = "Integer addition.";
  let arguments = (ins I32:$lhs, I32:$rhs);
  let results = (outs I32:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}

def Calc_MulOp : Calc_Op<"mul",
    [Pure, Commutative, SameOperandsAndResultType]> {
  let summary = "Integer multiplication.";
  let arguments = (ins I32:$lhs, I32:$rhs);
  let results = (outs I32:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}

// =============================================================================
// TASK: define `calc.print`, a side-effecting op.
//
// Target IR:
//
//     calc.print %x : i32
//
// Shape:
//   - one operand (`I32:$value`)
//   - NO result (prints don't produce values)
//   - assembly format: "$value attr-dict `:` type($value)"
//
// The interesting part is the *traits*. calc.print writes to stdout
// when eventually lowered, so it must NOT be DCE'd when its result is
// unused — except calc.print has no result, so DCE looks at it and
// thinks "no users, no observers, delete it." We have to tell MLIR
// the op DOES have a side effect.
//
// Two options:
//   (a) Add NO traits — MLIR assumes unknown effects, conservative.
//       The op survives DCE but the optimizer has no info to work with.
//   (b) Add `MemoryEffects<[MemWrite]>` — explicit "I write to memory."
//       Survives DCE, AND the optimizer knows this is a write so it
//       won't reorder it past other memory ops.
//
// Option (b) is the correct choice. (DO NOT add `Pure`. `Pure` would
// allow the canonicalizer to delete every print.)
// =============================================================================

// TODO: write `def Calc_PrintOp : Calc_Op<"print", [...]> { ... }` here.

#endif // CALC_DIALECT_TD
