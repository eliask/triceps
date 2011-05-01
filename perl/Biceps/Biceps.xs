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

#ifdef __cplusplus
extern "C"
#endif
XS(boot_Biceps__Label); 

MODULE = Biceps		PACKAGE = Biceps

BOOT:
# boot sub-packages that are compiled separately
boot_Biceps__Label(aTHX_ cv);

INCLUDE: RowType.xsh
INCLUDE: Row.xsh
INCLUDE: IndexType.xsh
INCLUDE: TableType.xsh
INCLUDE: Unit.xsh
INCLUDE: Table.xsh
INCLUDE: const-xs.inc

