//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The main file including all the parts of Biceps XS interface.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "BicepsPerl.h"

#include "const-c.inc"

MODULE = Biceps		PACKAGE = Biceps

INCLUDE: RowType.xsh
INCLUDE: Row.xsh
INCLUDE: IndexType.xsh
INCLUDE: TableType.xsh
INCLUDE: Unit.xsh
INCLUDE: Table.xsh
INCLUDE: const-xs.inc

