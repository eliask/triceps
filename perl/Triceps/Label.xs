//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Label.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

MODULE = Triceps::Label		PACKAGE = Triceps::Label

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
		Label *lab = self->get();

		// for casting of return value
		static char CLASS[] = "Triceps::RowType";
		RETVAL = new WrapRowType(const_cast<RowType *>(lab->getType()));
	OUTPUT:
		RETVAL

# returns 1 on success, 0 on error
int
chain(WrapLabel *self, WrapLabel *other)
	CODE:
		clearErrMsg();
		Label *lab = self->get();
		Label *olab = other->get();

		Erref err = lab->chain(olab);
		if (!err.isNull() && !err->isEmpty()) {
			setErrMsg("Triceps::Label::chain: " + err->print());
		}
		RETVAL = !err->hasError();
	OUTPUT:
		RETVAL

void
clearChained(WrapLabel *self)
	CODE:
		clearErrMsg();
		Label *lab = self->get();
		lab->clearChained();

# returns an array of references to chained objects
SV *
getChain(WrapLabel *self)
	PPCODE:
		clearErrMsg();
		Label *lab = self->get();

		// for casting of return value
		static char CLASS[] = "Triceps::Label";

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
		Label *lab = self->get();

		RETVAL = (char *)lab->getName().c_str();
	OUTPUT:
		RETVAL

void
setName(WrapLabel *self, char *name)
	CODE:
		clearErrMsg();
		Label *lab = self->get();
		lab->setName(name);

# check whether both refs point to the same type object
int
same(WrapLabel *self, WrapLabel *other)
	CODE:
		clearErrMsg();
		Label *lab = self->get();
		Label *olab = other->get();
		RETVAL = (lab == olab);
	OUTPUT:
		RETVAL

# factory for Rowops
WrapRowop *
makeRowop(WrapLabel *self, SV *opcode, WrapRow *row, ...)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::Rowop";

		char funcName[] = "Triceps::Label::makeRowop";

		clearErrMsg();
		Label *lab = self->get();
		const RowType *lt = lab->getType();
		const RowType *rt = row->ref_.getType();
		Row *r = row->ref_.get();

		if ((lt != rt) && !lt->match(rt)) {
			setErrMsg(strprintf("%s: row types do not match\n  Label:\n", funcName)
				+ lt->print("    ") + "\n  Row:\n" + rt->print("    ")
			);
			XSRETURN_UNDEF;
		}

		int intop;
		// accept opcode as either number of name
		if (SvIOK(opcode)) {
			intop = SvIV(opcode);
		} else {
			const char *opname = SvPV_nolen(opcode);
			intop = Rowop::stringOpcode(opname);
			if (intop == -1) {
				setErrMsg(strprintf("%s: unknown opcode string '%s', if integer was meant, it has to be cast", funcName, opname));
				XSRETURN_UNDEF;
			}
		}
		Rowop::Opcode op = (Rowop::Opcode)intop;

		Autoref<Rowop> rop;
		if (items == 3) {
			rop = new Rowop(lab, op, r);
		} else if (items == 4) {
			SV *enqMode = ST(3);
			int intem;
			// accept enqueueing mode as either number of name
			if (SvIOK(enqMode)) {
				intem = SvIV(enqMode);
				if (Gadget::emString(intem, NULL) == NULL) {
					setErrMsg(strprintf("%s: unknown enqueuing mode integer %d", funcName, intem));
					XSRETURN_UNDEF;
				}
				// em = (Gadget::EnqMode)intem;
			} else {
				const char *emname = SvPV_nolen(enqMode);
				intem = Gadget::stringEm(emname);
				if (intem == -1) {
					setErrMsg(strprintf("%s: unknown enqueuing mode string '%s', if integer was meant, it has to be cast", funcName, emname));
					XSRETURN_UNDEF;
				}
			}
			Gadget::EnqMode em = (Gadget::EnqMode)intem;

			rop = new Rowop(lab, op, r, em);
		} else {
			setErrMsg("Usage: Triceps::Label::makeRowop(label, opcode, row [, enqMode]), received too many arguments");
			XSRETURN_UNDEF;
		}

		RETVAL = new WrapRowop(rop);
	OUTPUT:
		RETVAL


# XXX add the rest of methods!
