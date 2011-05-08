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

		Gadget::EnqMode em;
		if (!parseEnqMode(funcName, enqMode, em))
			XSRETURN_UNDEF;

		Autoref<Table> t = tbt->makeTable(unit->get(), em, name);
		if (t.isNull()) {
			setErrMsg(strprintf("%s: table type was not successfully initialized", funcName));
			XSRETURN_UNDEF;
		}
		RETVAL = new WrapTable(t);
	OUTPUT:
		RETVAL

# XXX add the rest of methods
