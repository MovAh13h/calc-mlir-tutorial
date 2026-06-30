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
  // Tell ODS to generate `parseType` / `printType` dispatchers on the
  // dialect that route to each TypeDef's auto-generated parser/printer.
  // Without this you'd have to write the dispatcher by hand.
  let useDefaultTypePrinterParser = 1;
}

class Calc_Op<string mnemonic, list<Trait> traits = []>
    : Op<Calc_Dialect, mnemonic, traits>;

// Base class for our types. `TypeDef<dialect, name>` produces a C++
// class `mlir::calc::<name>Type`; the `mnemonic` is what shows up in
// `!calc.<mnemonic>` in textual IR.
class Calc_Type<string name, string typeMnemonic>
    : TypeDef<Calc_Dialect, name> {
  let mnemonic = typeMnemonic;
}

// -----------------------------------------------------------------------------
// !calc.fixed<INT_BITS, FRAC_BITS> — a parameterised fixed-point type.
//
// `parameters` declares the (typed) parameter list. The
// `assemblyFormat` declares how the textual form looks:
//
//   !calc.fixed<8, 8>      ← intBits=8, fracBits=8 (Q8.8)
//
// Verification:
//   - intBits + fracBits must be in {8, 16, 32, 64} (representable in
//     a standard integer container)
//   - fracBits must be > 0 (otherwise it's just an integer — use i32)
//
// The C++ class is `mlir::calc::FixedType`; auto-generated accessors
// are `getIntBits()` / `getFracBits()`.
// -----------------------------------------------------------------------------
def Calc_FixedType : Calc_Type<"Fixed", "fixed"> {
  let summary = "A fixed-point number with explicit int and frac bit widths.";
  let description = [{
    `!calc.fixed<int_bits, frac_bits>` represents a fixed-point number
    stored in an integer of `int_bits + frac_bits` total bits, where
    the low `frac_bits` are the fractional portion.
  }];
  let parameters = (ins "unsigned":$intBits, "unsigned":$fracBits);
  let assemblyFormat = "`<` $intBits `,` $fracBits `>`";
  let genVerifyDecl = 1;
}

// -----------------------------------------------------------------------------
// calc.fconst — fixed-point constant.
//
//   %x = calc.fconst 256 : !calc.fixed<8, 8>
//                 ↑ the raw bits of the Q8.8 value 1.0
//
// The integer attribute is the literal bit pattern; the encoding is
// implicit in the type. (So Q8.8 with value 1.0 is `256`, Q4.4 with
// value 1.0 is `16`, etc.)
// -----------------------------------------------------------------------------
def Calc_FConstOp : Calc_Op<"fconst", [Pure, ConstantLike]> {
  let summary = "Produce a fixed-point constant.";
  let arguments = (ins I64Attr:$value);
  let results = (outs Calc_FixedType:$result);
  let assemblyFormat = "$value attr-dict `:` type($result)";
}

// -----------------------------------------------------------------------------
// calc.fadd — fixed-point addition. With the same int/frac bit widths
// on both operands, this is just integer addition of the underlying
// bits — SameOperandsAndResultType enforces the agreement statically.
// -----------------------------------------------------------------------------
def Calc_FAddOp : Calc_Op<"fadd", [Pure, Commutative,
                                    SameOperandsAndResultType]> {
  let summary = "Fixed-point addition.";
  let arguments = (ins Calc_FixedType:$lhs, Calc_FixedType:$rhs);
  let results = (outs Calc_FixedType:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}

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
