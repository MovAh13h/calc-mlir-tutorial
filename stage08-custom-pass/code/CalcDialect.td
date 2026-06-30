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

  // Tell ODS we want a materializeConstant hook on the dialect class.
  // When a fold returns an Attribute, the canonicalizer calls this to
  // create a new ConstOp (or whatever) carrying that attribute.
  let hasConstantMaterializer = 1;
}

class Calc_Op<string mnemonic, list<Trait> traits = []>
    : Op<Calc_Dialect, mnemonic, traits>;

// -----------------------------------------------------------------------------
// calc.const (unchanged).
// -----------------------------------------------------------------------------
def Calc_ConstOp : Calc_Op<"const", [Pure, ConstantLike]> {
  let summary = "Produce a 32-bit integer constant.";
  let arguments = (ins I32Attr:$value);
  let results = (outs I32:$result);
  let assemblyFormat = "$value attr-dict `:` type($result)";
  let hasFolder = 1;  // const folds to its value attribute
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
  let hasCanonicalizer = 1;
  let hasFolder = 1;       // fold const+const → const
}

def Calc_MulOp : Calc_Op<"mul",
    [Pure, Commutative, SameOperandsAndResultType]> {
  let summary = "Integer multiplication.";
  let arguments = (ins I32:$lhs, I32:$rhs);
  let results = (outs I32:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
  let hasCanonicalizer = 1;
  let hasFolder = 1;       // fold const*const → const
}

// -----------------------------------------------------------------------------
// calc.print — side-effecting op (will lower to printf in stage 10/11).
//
//     calc.print %x : i32
//
// Traits:
//   - MemoryEffects<[MemWrite]> says "this op writes somewhere
//     observable" (in our case, stdout). The canonicalizer / DCE see
//     this and refuse to delete the op, even if its result is unused
//     (and indeed it has no result).
//
// Note the deliberate absence of `Pure`. Adding `Pure` here would
// allow the canonicalizer to delete every print, which is exactly the
// opposite of what we want.
// -----------------------------------------------------------------------------
def Calc_PrintOp : Calc_Op<"print", [MemoryEffects<[MemWrite]>]> {
  let summary = "Print an i32 to stdout (lowered to printf later).";
  let arguments = (ins I32:$value);
  // No results — print is consumed for its side effect, not a value.
  let assemblyFormat = "$value attr-dict `:` type($value)";
}

// -----------------------------------------------------------------------------
// calc.shr — logical shift right by an i32 amount.
//
//     %r = calc.shr %x, %amount : i32
//
// Sets `hasVerifier = 1`, which tells ODS to declare a `verify()`
// method on the generated C++ class. We then implement that method
// by hand in CalcDialect.cpp. The custom check: if $amount is a
// statically known calc.const, its value must be in [0, 31];
// otherwise we can't check (it's a runtime value) and we accept.
// -----------------------------------------------------------------------------
def Calc_ShrOp : Calc_Op<"shr",
    [Pure, SameOperandsAndResultType]> {
  let summary = "Logical shift right.";
  let arguments = (ins I32:$value, I32:$amount);
  let results = (outs I32:$result);
  let assemblyFormat = "$value `,` $amount attr-dict `:` type($result)";
  let hasVerifier = 1;
}

#endif // CALC_DIALECT_TD
