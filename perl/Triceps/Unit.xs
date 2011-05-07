//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Unit.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

MODULE = Triceps::Unit		PACKAGE = Triceps::Unit
###################################################################################

void
DESTROY(WrapUnit *self)
	CODE:
		// warn("Unit destroyed!");
		delete self;


WrapUnit *
Triceps::Unit::new(char *name)
	CODE:
		clearErrMsg();

		RETVAL = new WrapUnit(new Unit(name));
	OUTPUT:
		RETVAL

WrapTable *
makeTable(WrapUnit *unit, WrapTableType *wtt, SV *enqMode, char *name)
	CODE:
		char funcName[] = "Triceps::Unit::makeTable";
		// for casting of return value
		static char CLASS[] = "Triceps::Table";

		clearErrMsg();
		TableType *tbt = wtt->get();

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

		Autoref<Table> t = tbt->makeTable(unit->get(), em, name);
		if (t.isNull()) {
			setErrMsg(strprintf("%s: table type was not successfully initialized", funcName));
			XSRETURN_UNDEF;
		}
		RETVAL = new WrapTable(t);
	OUTPUT:
		RETVAL

# XXX add the rest of methods
