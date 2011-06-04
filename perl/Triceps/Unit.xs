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

# returns true on success, undef on error;
# the argument array can be a mix of rowops and trays;
# on error some of the records may end up enqueued
int
schedule(WrapUnit *self, ...)
	CODE:
		static char funcName[] =  "Triceps::Unit::schedule";
		clearErrMsg();
		Unit *u = self->get();
		for (int i = 1; i < items; i++) {
			if (!enqueueSv(funcName, u, Gadget::EM_SCHEDULE, ST(i), i))
				XSRETURN_UNDEF;
		}
		RETVAL = 1;
	OUTPUT:
		RETVAL

# see comment for schedule
int
fork(WrapUnit *self, ...)
	CODE:
		static char funcName[] =  "Triceps::Unit::fork";
		clearErrMsg();
		Unit *u = self->get();
		for (int i = 1; i < items; i++) {
			if (!enqueueSv(funcName, u, Gadget::EM_FORK, ST(i), i))
				XSRETURN_UNDEF;
		}
		RETVAL = 1;
	OUTPUT:
		RETVAL

# see comment for schedule
int
call(WrapUnit *self, ...)
	CODE:
		static char funcName[] =  "Triceps::Unit::call";
		clearErrMsg();
		Unit *u = self->get();
		for (int i = 1; i < items; i++) {
			if (!enqueueSv(funcName, u, Gadget::EM_CALL, ST(i), i))
				XSRETURN_UNDEF;
		}
		RETVAL = 1;
	OUTPUT:
		RETVAL

# see comment for schedule
int
enqueue(WrapUnit *self, SV *enqMode, ...)
	CODE:
		static char funcName[] =  "Triceps::Unit::enqueue";
		clearErrMsg();
		Unit *u = self->get();
		Gadget::EnqMode em;

		if (!parseEnqMode(funcName, enqMode, em))
			XSRETURN_UNDEF;

		for (int i = 2; i < items; i++) {
			if (!enqueueSv(funcName, u, em, ST(i), i))
				XSRETURN_UNDEF;
		}
		RETVAL = 1;
	OUTPUT:
		RETVAL

void
callNext(WrapUnit *self)
	CODE:
		clearErrMsg();
		Unit *u = self->get();
		u->callNext();

void
drainFrame(WrapUnit *self)
	CODE:
		clearErrMsg();
		Unit *u = self->get();
		u->drainFrame();

int
empty(WrapUnit *self)
	CODE:
		clearErrMsg();
		Unit *u = self->get();
		RETVAL = u->empty();
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

# operations on unit name
char *
getName(WrapUnit *self)
	CODE:
		clearErrMsg();
		Unit *u = self->get();
		RETVAL = (char *)u->getName().c_str();
	OUTPUT:
		RETVAL

void 
setName(WrapUnit *self, char *name)
	CODE:
		clearErrMsg();
		Unit *u = self->get();
		u->setName(name);

WrapTable *
makeTable(WrapUnit *unit, WrapTableType *wtt, SV *enqMode, char *name)
	CODE:
		static char funcName[] =  "Triceps::Unit::makeTable";
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
		static char funcName[] =  "Triceps::Unit::makeTray";
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

# make a label without any executable code (that is useful for chaining)
WrapLabel *
makeDummyLabel(WrapUnit *self, WrapRowType *wrt, char *name)
	CODE:
		static char funcName[] =  "Triceps::Unit::makeDummyLabel";
		// for casting of return value
		static char CLASS[] = "Triceps::Label";

		clearErrMsg();
		Unit *unit = self->get();
		RowType *rt = wrt->get();

		RETVAL = new WrapLabel(new DummyLabel(unit, rt, name));
	OUTPUT:
		RETVAL

# make a label with executable Perl code
# XXX add extra Perl arguments to pass to code
WrapLabel *
makeLabel(WrapUnit *self, WrapRowType *wrt, char *name, ...)
	CODE:
		static char funcName[] =  "Triceps::Unit::makeLabel";
		// for casting of return value
		static char CLASS[] = "Triceps::Label";

		clearErrMsg();
		Unit *unit = self->get();
		RowType *rt = wrt->get();

		Onceref<PerlCallback> cb = new PerlCallback();
		PerlCallbackInitialize(cb, funcName, 3, items-3);
		if (cb->code_ == NULL)
			XSRETURN_UNDEF; // error message is already set

		RETVAL = new WrapLabel(new PerlLabel(unit, rt, name, cb));
	OUTPUT:
		RETVAL

# XXX add the rest of methods
