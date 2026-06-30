#ifndef CALC_DIALECT_TD
#define CALC_DIALECT_TD

include "mlir/IR/OpBase.td"
include "mlir/IR/AttrTypeBase.td"
include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

// -----------------------------------------------------------------------------
// Dialect + helper base classes.
// -----------------------------------------------------------------------------
def Calc_Dialect : Dialect {
  let name = "calc";
  let summary = "A tutorial dialect for arithmetic over i32 and fixed-point.";
  let cppNamespace = "::mlir::calc";

  let hasConstantMaterializer = 1;

  // TODO (Task 1) — add this line:
  //
  //   let useDefaultTypePrinterParser = 1;
  //
  // It tells ODS to generate `parseType` / `printType` dispatchers
  // on the dialect that route to each TypeDef's auto-generated
  // parser/printer. Without it, you'd have to write the dispatcher
  // by hand.
}

class Calc_Op<string mnemonic, list<Trait> traits = []>
    : Op<Calc_Dialect, mnemonic, traits>;

// TODO (Task 2) — define a base class for our types AND the FixedType:
//
//   class Calc_Type<string name, string typeMnemonic>
//       : TypeDef<Calc_Dialect, name> {
//     let mnemonic = typeMnemonic;
//   }
//
//   def Calc_FixedType : Calc_Type<"Fixed", "fixed"> {
//     let summary = "A fixed-point number with explicit int/frac bit widths.";
//     let parameters = (ins "unsigned":$intBits, "unsigned":$fracBits);
//     let assemblyFormat = "`<` $intBits `,` $fracBits `>`";
//     let genVerifyDecl = 1;     // generate a `verify(...)` declaration
//   }
//
// `genVerifyDecl = 1` declares the verifier; you'll implement the body
// in CalcDialect.cpp.
//
// The result: a C++ class `mlir::calc::FixedType` with auto-generated
// accessors `getIntBits()` / `getFracBits()` and a `get(ctx, intBits,
// fracBits)` builder.

// TODO (Task 3) — declare two ops that use the new type:
//
//   def Calc_FConstOp : Calc_Op<"fconst", [Pure, ConstantLike]> {
//     let summary = "Produce a fixed-point constant.";
//     let arguments = (ins I64Attr:$value);
//     let results = (outs Calc_FixedType:$result);
//     let assemblyFormat = "$value attr-dict `:` type($result)";
//   }
//
//   def Calc_FAddOp : Calc_Op<"fadd", [Pure, Commutative,
//                                       SameOperandsAndResultType]> {
//     let summary = "Fixed-point addition.";
//     let arguments = (ins Calc_FixedType:$lhs, Calc_FixedType:$rhs);
//     let results = (outs Calc_FixedType:$result);
//     let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
//   }

// -----------------------------------------------------------------------------
// calc.const (unchanged from earlier stages).
// -----------------------------------------------------------------------------
def Calc_ConstOp : Calc_Op<"const", [Pure, ConstantLike]> {
  let summary = "Produce a 32-bit integer constant.";
  let arguments = (ins I32Attr:$value);
  let results = (outs I32:$result);
  let assemblyFormat = "$value attr-dict `:` type($result)";
  let hasFolder = 1;
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
  let hasFolder = 1;
}

def Calc_MulOp : Calc_Op<"mul",
    [Pure, Commutative, SameOperandsAndResultType]> {
  let summary = "Integer multiplication.";
  let arguments = (ins I32:$lhs, I32:$rhs);
  let results = (outs I32:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
  let hasCanonicalizer = 1;
  let hasFolder = 1;
}

// -----------------------------------------------------------------------------
// calc.print (unchanged).
// -----------------------------------------------------------------------------
def Calc_PrintOp : Calc_Op<"print", [MemoryEffects<[MemWrite]>]> {
  let summary = "Print an i32 to stdout (lowered to printf in stage 10).";
  let arguments = (ins I32:$value);
  let assemblyFormat = "$value attr-dict `:` type($value)";
}

// -----------------------------------------------------------------------------
// calc.shr (unchanged).
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
