// calc-opt: an mlir-opt-style driver that also knows about our calc dialect.
//
// Differences from upstream mlir-opt:
//   - we register all built-in dialects + passes, AND
//   - we register our CalcDialect.
//
// Use it exactly like mlir-opt:
//   calc-opt --help
//   calc-opt --show-dialects
//   calc-opt input.mlir
//   calc-opt --canonicalize input.mlir

#include "CalcDialect.h"

#include "mlir/IR/DialectRegistry.h"
#include "mlir/InitAllDialects.h"
#include "mlir/InitAllPasses.h"
#include "mlir/Tools/mlir-opt/MlirOptMain.h"

int main(int argc, char **argv) {
  mlir::DialectRegistry registry;
  mlir::registerAllDialects(registry);
  mlir::registerAllPasses();
  registry.insert<mlir::calc::CalcDialect>();
  return mlir::asMainReturnCode(
      mlir::MlirOptMain(argc, argv, "calc-opt", registry));
}
