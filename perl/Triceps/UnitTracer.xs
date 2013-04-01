//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Unit::Tracer and its subclasses.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "PerlCallback.h"

// see also translateUnitTracerSubclass() in TricepsPerl.*

MODULE = Triceps::UnitTracer		PACKAGE = Triceps::UnitTracer
###################################################################################

int
CLONE_SKIP(...)
	CODE:
		RETVAL = 1;
	OUTPUT:
		RETVAL

void
DESTROY(WrapUnitTracer *self)
	CODE:
		// warn("UnitTracer destroyed!");
		delete self;


#// to test a common call
int
__testSuperclassCall(WrapUnitTracer *self)
	CODE:
		RETVAL = 1;
	OUTPUT:
		RETVAL

#// check whether both refs point to the same object
int
same(WrapUnitTracer *self, WrapUnitTracer *other)
	CODE:
		clearErrMsg();
		Unit::Tracer *t = self->get();
		Unit::Tracer *ot = other->get();
		RETVAL = (t == ot);
	OUTPUT:
		RETVAL

MODULE = Triceps::UnitTracer		PACKAGE = Triceps::UnitTracerStringName
###################################################################################

#// args are a hash of options
WrapUnitTracer *
new(char *CLASS, ...)
	CODE:
		clearErrMsg();
		// defaults for options
		bool verbose = false;

		if (items % 2 != 1) {
			setErrMsg("Usage: Triceps::UnitTracerStringName::new(CLASS, optionName, optionValue, ...), option names and values must go in pairs");
			XSRETURN_UNDEF;
		}
		for (int i = 1; i < items; i += 2) {
			const char *optname = (const char *)SvPV_nolen(ST(i));
			if (!strcmp(optname, "verbose")) {
				verbose = (SvIV(ST(i+1)) != 0);
			} else {
				setErrMsg(strprintf("Triceps::UnitTracerStringName::new: unknown option '%s'", optname));
				XSRETURN_UNDEF;
			}
		}

		// for casting of return value
		RETVAL = new WrapUnitTracer(new Unit::StringNameTracer(verbose));
	OUTPUT:
		RETVAL

#// getBuffer() would imply getting the error buffer, so call it just print()
char *
print(WrapUnitTracer *self)
	CODE:
		clearErrMsg();
		Unit::Tracer *tracer = self->get();
		Unit::StringNameTracer *sntr = dynamic_cast<Unit::StringNameTracer *>(tracer);
		if (sntr == NULL)
			XSRETURN_UNDEF;
		string msg = sntr->getBuffer()->print();
		RETVAL = (char *)msg.c_str();
	OUTPUT:
		RETVAL

void
clearBuffer(WrapUnitTracer *self)
	CODE:
		clearErrMsg();
		Unit::Tracer *tracer = self->get();
		Unit::StringNameTracer *sntr = dynamic_cast<Unit::StringNameTracer *>(tracer);
		if (sntr != NULL)
			sntr->clearBuffer();

#// to test a subclass call
char *
__testSubclassCall(WrapUnitTracer *self)
	CODE:
		clearErrMsg();
		Unit::Tracer *tracer = self->get();
		Unit::StringNameTracer *sntr = dynamic_cast<Unit::StringNameTracer *>(tracer);
		if (sntr == NULL)
			XSRETURN_UNDEF;
		RETVAL = (char *)"UnitTracerStringName";
	OUTPUT:
		RETVAL

MODULE = Triceps::UnitTracer		PACKAGE = Triceps::UnitTracerPerl
###################################################################################

WrapUnitTracer *
new(char *CLASS, ...)
	CODE:
		static char funcName[] =  "Triceps::UnitTracerPerl::new";
		clearErrMsg();

		Onceref<PerlCallback> cb = new PerlCallback();
		PerlCallbackInitialize(cb, funcName, 1, items-1);
		if (cb->code_ == NULL)
			XSRETURN_UNDEF; // error message is already set

		RETVAL = new WrapUnitTracer(new UnitTracerPerl(cb));
	OUTPUT:
		RETVAL

#// to test a subclass call
char *
__testSubclassCall(WrapUnitTracer *self)
	CODE:
		clearErrMsg();
		Unit::Tracer *tracer = self->get();
		UnitTracerPerl *ptr = dynamic_cast<UnitTracerPerl *>(tracer);
		if (ptr == NULL)
			XSRETURN_UNDEF;
		RETVAL = (char *)"UnitTracerPerl";
	OUTPUT:
		RETVAL

#// XXX add getCode
#// XXX getCode should return an array?
