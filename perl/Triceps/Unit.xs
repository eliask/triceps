//
// (C) Copyright 2011 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Unit.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "PerlCallback.h"

MODULE = Triceps::Unit		PACKAGE = Triceps::Unit
###################################################################################

void
DESTROY(WrapUnit *self)
	CODE:
		Unit *unit = self->get();
		// warn("Unit %s %p wrap %p destroyed!", unit->getName().c_str(), unit, self);
		delete self;


WrapUnit *
Triceps::Unit::new(char *name)
	CODE:
		clearErrMsg();

		Autoref<Unit> unit = new Unit(name);
		WrapUnit *wu = new WrapUnit(unit);
		// warn("Created unit %s %p wrap %p", name, unit.get(), wu);
		RETVAL = wu;
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
			if (!enqueueSv(funcName, u, NULL, Gadget::EM_SCHEDULE, ST(i), i))
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
			if (!enqueueSv(funcName, u, NULL, Gadget::EM_FORK, ST(i), i))
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
			if (!enqueueSv(funcName, u, NULL, Gadget::EM_CALL, ST(i), i))
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
			if (!enqueueSv(funcName, u, NULL, em, ST(i), i))
				XSRETURN_UNDEF;
		}
		RETVAL = 1;
	OUTPUT:
		RETVAL

# work with marks
void
setMark(WrapUnit *self, WrapFrameMark *wm)
	CODE:
		static char funcName[] =  "Triceps::Unit::setMark";
		clearErrMsg();
		Unit *u = self->get();
		FrameMark *mark = wm->get();
		u->setMark(mark);

# see comment for schedule
int
loopAt(WrapUnit *self, WrapFrameMark *wm, ...)
	CODE:
		static char funcName[] =  "Triceps::Unit::loopAt";
		clearErrMsg();
		Unit *u = self->get();
		FrameMark *mark = wm->get();
		Unit *mu = mark->getUnit();
		if (mu != NULL && mu != u) {
			setErrMsg( strprintf("%s: mark belongs to a different unit '%s'", funcName, mu->getName().c_str()) );
			XSRETURN_UNDEF;
		}
		for (int i = 2; i < items; i++) {
			if (!enqueueSv(funcName, u, mark, Gadget::EM_FORK, ST(i), i))
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

# check whether both refs point to the same object
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

# operations on tracer
WrapUnitTracer *
getTracer(WrapUnit *self)
	CODE:
		clearErrMsg();
		Unit *u = self->get();
		Autoref<Unit::Tracer> tracer = u->getTracer();
		if (tracer.isNull())
			XSRETURN_UNDEF;

		// find the class to use for blessing
		char *CLASS = translateUnitTracerSubclass(tracer.get());
		RETVAL = new WrapUnitTracer(tracer);
	OUTPUT:
		RETVAL

# use SV* for argument because may pass undef
void
setTracer(WrapUnit *self, SV *arg)
	CODE:
		clearErrMsg();
		Unit *u = self->get();
		Unit::Tracer *tracer = NULL;
		if (SvOK(arg)) {
			if( sv_isobject(arg) && (SvTYPE(SvRV(arg)) == SVt_PVMG) ) {
				WrapUnitTracer *twrap = (WrapUnitTracer *)SvIV((SV*)SvRV( arg ));
				if (twrap == 0 || twrap->badMagic()) {
					setErrMsg( "Unit::setTracer: tracer has an incorrect magic for WrapUnitTracer" );
					XSRETURN_UNDEF;
				}
				tracer = twrap->get();
			} else{
				setErrMsg( "Unit::setTracer: tracer is not a blessed SV reference to WrapUnitTracer" );
				XSRETURN_UNDEF;
			}
		} // otherwise leave the tracer as NULL
		u->setTracer(tracer);

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
				if (var->get()->getLabel()->getUnitPtr() != unit) {
					setErrMsg( strprintf("%s: argument %d is a Rowop for label %s from a wrong unit %s", funcName, i,
						var->get()->getLabel()->getName().c_str(), var->get()->getLabel()->getUnitName().c_str()) );
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
# @param self - unit where the new label belongs
# @param wrt - row type for the label
# @param name - name o fthe label
# @param clear - the Perl function reference to be called when the label gets cleared,
#        may be undef
# @param exec - the Perl function reference for label execution
# @param ... - extra args used for both clear and exec callbacks
WrapLabel *
makeLabel(WrapUnit *self, WrapRowType *wrt, char *name, SV *clear, SV *exec, ...)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::Label";

		clearErrMsg();
		Unit *unit = self->get();
		RowType *rt = wrt->get();

		Onceref<PerlCallback> clr;
		if (SvOK(clear)) {
			clr = new PerlCallback();
			PerlCallbackInitializeSplit(clr, "Triceps::Unit::makeLabel(clear)", clear, 5, items-5);
			if (clr->code_ == NULL)
				XSRETURN_UNDEF; // error message is already set
		}

		Onceref<PerlCallback> cb = new PerlCallback();
		PerlCallbackInitialize(cb, "Triceps::Unit::makeLabel(callback)", 4, items-4);
		if (cb->code_ == NULL)
			XSRETURN_UNDEF; // error message is already set

		RETVAL = new WrapLabel(new PerlLabel(unit, rt, name, clr, cb));
	OUTPUT:
		RETVAL

# clear the labels, makes the unit non-runnable
void
clearLabels(WrapUnit *self)
	CODE:
		clearErrMsg();
		Unit *unit = self->get();
		unit->clearLabels();

# make a clearing trigger
# (once it's destroyed, the unit will get cleared!)
WrapUnitClearingTrigger *
makeClearingTrigger(WrapUnit *self)
	CODE:
		static char funcName[] =  "Triceps::Unit::makeLabel";
		// for casting of return value
		static char CLASS[] = "Triceps::UnitClearingTrigger";

		clearErrMsg();
		Unit *unit = self->get();

		RETVAL = new WrapUnitClearingTrigger(new UnitClearingTrigger(unit));
	OUTPUT:
		RETVAL

MODULE = Triceps::Unit		PACKAGE = Triceps::UnitClearingTrigger
###################################################################################

void
DESTROY(WrapUnitClearingTrigger *self)
	CODE:
		// warn("UnitClearingTrigger destroyed!");
		delete self;

