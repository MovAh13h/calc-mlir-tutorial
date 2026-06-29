#pragma once

#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"

// Generated dialect class.
#include "CalcDialect.h.inc"

// Generated op class declarations.
#define GET_OP_CLASSES
#include "CalcOps.h.inc"
