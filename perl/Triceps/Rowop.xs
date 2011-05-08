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

# make a copy of Rowop
WrapRowop *
copy(WrapRowop *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::Rowop";
		clearErrMsg();
		Rowop *rop = self->get();
		RETVAL = new WrapRowop(new Rowop(*rop));
	OUTPUT:
		RETVAL

# check whether both refs point to the same type object
int
same(WrapRowop *self, WrapRowop *other)
	CODE:
		clearErrMsg();
		Rowop *rop = self->get();
		Rowop *orop = other->get();
		RETVAL = (rop == orop);
	OUTPUT:
		RETVAL

int
getOpcode(WrapRowop *self)
	CODE:
		clearErrMsg();
		Rowop *rop = self->get();
		RETVAL = rop->getOpcode();
	OUTPUT:
		RETVAL

int
isInsert(WrapRowop *self)
	CODE:
		clearErrMsg();
		Rowop *rop = self->get();
		RETVAL = rop->isInsert();
	OUTPUT:
		RETVAL
