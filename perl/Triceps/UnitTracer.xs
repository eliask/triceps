//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Unit::Tracer and its subclasses.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

// for now just a dummy, to fill out later
class PerlUnitTracer : public Unit::Tracer
{
public:
	// from Unit::Tracer
	virtual void execute(Unit *unit, const Label *label, const Label *fromLabel, Rowop *rop, Unit::TracerWhen when)
	{
		// XXX call a Perl function
	}
};

MODULE = Triceps::UnitTracer		PACKAGE = Triceps::UnitTracer
###################################################################################

void
DESTROY(WrapUnitTracer *self)
	CODE:
		// warn("UnitTracer destroyed!");
		delete self;


# to test a common call
int
testSuperclassCall(WrapUnitTracer *self)
	CODE:
		RETVAL = 1;
	OUTPUT:
		RETVAL

MODULE = Triceps::UnitTracer		PACKAGE = Triceps::UnitTracerStringName
###################################################################################

# args are a hash of options
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


# to test a subclass call
char *
testSubclassCall(WrapUnitTracer *self)
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

# XXX for now just create a dummy object
WrapUnitTracer *
new(char *CLASS)
	CODE:
		clearErrMsg();
		RETVAL = new WrapUnitTracer(new PerlUnitTracer());
	OUTPUT:
		RETVAL

# to test a subclass call
char *
testSubclassCall(WrapUnitTracer *self)
	CODE:
		clearErrMsg();
		Unit::Tracer *tracer = self->get();
		PerlUnitTracer *ptr = dynamic_cast<PerlUnitTracer *>(tracer);
		if (ptr == NULL)
			XSRETURN_UNDEF;
		RETVAL = (char *)"UnitTracerPerl";
	OUTPUT:
		RETVAL

# XXX put in the real logic!
