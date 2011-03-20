//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The main file including all the parts of Biceps XS interface.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "const-c.inc"

#include "BicepsPerl.h"

MODULE = Biceps		PACKAGE = Biceps

INCLUDE: RowType.xsh
INCLUDE: Row.xsh

