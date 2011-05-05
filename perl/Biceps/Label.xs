//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Label.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "BicepsPerl.h"

MODULE = Biceps::Label		PACKAGE = Biceps::Label

###################################################################################

BOOT:
// fprintf(stderr, "DEBUG Label items=%d sp=%p mark=%p\n", items, sp, mark);

void
DESTROY(WrapLabel *self)
	CODE:
		// warn("Label destroyed!");
		delete self;

# XXX add the rest of methods!
