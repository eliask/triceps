//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Rowop.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

MODULE = Triceps::Rowop		PACKAGE = Triceps::Rowop
###################################################################################

BOOT:
// fprintf(stderr, "DEBUG Rowop items=%d sp=%p mark=%p\n", items, sp, mark);

void
DESTROY(WrapRowop *self)
	CODE:
		// warn("Rowop destroyed!");
		delete self;


