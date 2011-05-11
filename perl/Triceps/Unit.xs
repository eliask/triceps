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

# check whether both refs point to the same type object
int
same(WrapUnit *self, WrapUnit *other)
	CODE:
		clearErrMsg();
		Unit *u = self->get();
		Unit *ou = other->get();
		RETVAL = (u == ou);
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

WrapTray *
makeTray(WrapUnit *self, ...)
	CODE:
		char funcName[] = "Triceps::Unit::makeTray";
		// for casting of return value
		static char CLASS[] = "Triceps::Tray";

		clearErrMsg();
		Unit *unit = self->get();

		for (int i = 1; i < items; i++) {
			SV *arg = ST(i);
			if( sv_isobject(arg) && (SvTYPE(SvRV(arg)) == SVt_PVMG) ) {
				WrapRowop *var = (WrapRowop *)SvIV((SV*)SvRV( arg ));
				if (var == 0 || var->badMagic()) {
					setErrMsg( strprintf("%s: argument %d has an incorrect magic for Rowop", funcName, i) );
					XSRETURN_UNDEF;
				}
				if (var->get()->getLabel()->getUnit() != unit) {
					setErrMsg( strprintf("%s: argument %d is a Rowop for label %s from a wrong unit %s", funcName, i,
						var->get()->getLabel()->getName().c_str(), var->get()->getLabel()->getUnit()->getName().c_str()) );
					XSRETURN_UNDEF;
				}
			} else{
				setErrMsg( strprintf("%s: argument %d is not a blessed SV reference to Rowop", funcName, i) );
				XSRETURN_UNDEF;
			}
		}

		Autoref<Tray> tray = new Tray;
		for (int i = 1; i < items; i++) {
			SV *arg = ST(i);
			WrapRowop *var = (WrapRowop *)SvIV((SV*)SvRV( arg ));
			tray->push_back(var->get());
		}
		RETVAL = new WrapTray(unit, tray);
	OUTPUT:
		RETVAL

# XXX add the rest of methods
