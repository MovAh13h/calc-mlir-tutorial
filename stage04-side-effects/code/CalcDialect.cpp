#include "CalcDialect.h"

using namespace mlir;
using namespace mlir::calc;

#include "CalcDialect.cpp.inc"

#define GET_OP_CLASSES
#include "CalcOps.cpp.inc"

void CalcDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "CalcOps.cpp.inc"
      >();
}
