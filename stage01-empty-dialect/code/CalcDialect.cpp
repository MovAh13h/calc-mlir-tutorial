#include "CalcDialect.h"

using namespace mlir;
using namespace mlir::calc;

// Pulls in the generated CalcDialect class definition (constructor that
// calls initialize(), etc.).
#include "CalcDialect.cpp.inc"

void CalcDialect::initialize() {
  // No ops, types, or attributes registered yet — that's stage 02 onward.
}
