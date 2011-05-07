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

# returns 1 on success, 0 on error
int
chain(WrapLabel *self, WrapLabel *other)
	CODE:
		clearErrMsg();
		Label *lab = self->ref_.get();
		Label *olab = other->ref_.get();

		Erref err = lab->chain(olab);
		if (!err.isNull() && !err->isEmpty()) {
			setErrMsg("Biceps::Label::chain: " + err->print());
		}
		RETVAL = !err->hasError();
	OUTPUT:
		RETVAL

void
clearChained(WrapLabel *self)
	CODE:
		clearErrMsg();
		Label *lab = self->ref_.get();
		lab->clearChained();

# returns an array of references to chained objects
SV *
getChain(WrapLabel *self)
	PPCODE:
		clearErrMsg();
		Label *lab = self->get();

		// for casting of return value
		static char CLASS[] = "Biceps::Label";

		const Label::ChainedVec &cv = lab->getChain();
		int nf = cv.size();
		for (int i = 0; i < nf; i++) {
			WrapLabel *cl = new WrapLabel(cv[i].get());

			SV *sv = newSV(0);
			sv_setref_pv( sv, CLASS, (void*)cl );
			XPUSHs(sv_2mortal(sv));
		}

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
