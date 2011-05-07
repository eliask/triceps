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

WrapRowType*
getType(WrapLabel *self)
	CODE:
		clearErrMsg();
		Label *lab = self->ref_.get();

		// for casting of return value
		static char CLASS[] = "Biceps::RowType";
		RETVAL = new WrapRowType(const_cast<RowType *>(lab->getType()));
	OUTPUT:
		RETVAL

char *
getName(WrapLabel *self)
	CODE:
		clearErrMsg();
		Label *lab = self->ref_.get();

		RETVAL = (char *)lab->getName().c_str();
	OUTPUT:
		RETVAL

void
setName(WrapLabel *self, char *name)
	CODE:
		clearErrMsg();
		Label *lab = self->ref_.get();
		lab->setName(name);

# XXX add the rest of methods!
