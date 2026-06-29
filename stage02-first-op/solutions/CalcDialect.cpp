#include "CalcDialect.h"

using namespace mlir;
using namespace mlir::calc;

// Generated dialect class definition.
#include "CalcDialect.cpp.inc"

// Generated op class definitions.
#define GET_OP_CLASSES
#include "CalcOps.cpp.inc"

void CalcDialect::initialize() {
  // Register every op declared in CalcOps.cpp.inc. The GET_OP_LIST
  // macro expands to a comma-separated list of op types.
  addOperations<
#define GET_OP_LIST
#include "CalcOps.cpp.inc"
      >();
}
