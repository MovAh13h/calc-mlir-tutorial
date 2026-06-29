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

// =============================================================================
// TASK: define `calc.const`, an i32 constant op.
//
// We want the printed/parsed form:
//
//     %x = calc.const 42 : i32
//
// You need a `def Calc_ConstOp : Calc_Op<"const", [...]> { ... }` with:
//
//   - traits: at minimum `[Pure]` (constants have no side effects)
//   - arguments: `(ins I32Attr:$value)` — a signless-32-bit integer
//                attribute holding the constant value
//   - results:   `(outs I32:$result)` — produces one i32 SSA value
//   - assemblyFormat: `"$value attr-dict `:` type($result)"`
//
// What each piece does:
//   * I32Attr is the *compile-time* literal. It lives in the op's
//     attribute dictionary; it isn't an SSA operand.
//   * I32 (in `results`) says the result is exactly type `i32`.
//   * The assembly format string is a tiny DSL:
//       $value       — print/parse the value attribute
//       attr-dict    — optional `{k = v, ...}` attribute dict
//       `:`          — literal colon
//       type($result) — print/parse the result type
//
// If you get stuck, see solutions/CalcDialect.td.
// =============================================================================

// TODO: write `def Calc_ConstOp : Calc_Op<"const", [Pure]> { ... }` here.

#endif // CALC_DIALECT_TD
