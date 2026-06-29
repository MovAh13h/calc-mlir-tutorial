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
// ============================================================================
// TASK (part of stage 06): add `let hasCanonicalizer = 1;` to BOTH
// Calc_AddOp and Calc_MulOp below. This flag tells ODS to declare the
// `getCanonicalizationPatterns` method that you'll implement in C++.
// (See the matching TODO in CalcDialect.cpp.)
// ============================================================================
def Calc_AddOp : Calc_Op<"add",
    [Pure, Commutative, SameOperandsAndResultType]> {
  let summary = "Integer addition.";
  let arguments = (ins I32:$lhs, I32:$rhs);
  let results = (outs I32:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
  // TODO: add `let hasCanonicalizer = 1;` here.
}

def Calc_MulOp : Calc_Op<"mul",
    [Pure, Commutative, SameOperandsAndResultType]> {
  let summary = "Integer multiplication.";
  let arguments = (ins I32:$lhs, I32:$rhs);
  let results = (outs I32:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
  // TODO: add `let hasCanonicalizer = 1;` here.
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
