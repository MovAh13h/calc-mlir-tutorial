#pragma once

#include "CalcDialect.h"

#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Pass/Pass.h"

namespace mlir {
namespace calc {

#define GEN_PASS_DECL
#include "CalcPasses.h.inc"

std::unique_ptr<Pass> createCalcStrengthReducePass();
std::unique_ptr<Pass> createCalcToArithPass();

#define GEN_PASS_REGISTRATION
#include "CalcPasses.h.inc"

} // namespace calc
} // namespace mlir
