//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for AggregatorType.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "PerlCallback.h"
#include "PerlAggregator.h"

MODULE = Triceps::AggregatorType		PACKAGE = Triceps::AggregatorType
###################################################################################

void
DESTROY(WrapAggregatorType *self)
	CODE:
		// warn("AggregatorType destroyed!");
		delete self;


# @param CLASS - name of type being constructed
# @param wrt - row type of the aggregation result
# @param name - name that will be used to create the aggregator gadget in the table
# @param constructor - function reference, called to create the state of aggregator
#        for each index (may be undef)
# @param handler - function reference used to react to strings being added and removed
# @param ... - extra args used for both constructor and handler
WrapAggregatorType *
new(char *CLASS, WrapRowType *wrt, char *name, SV *constructor, SV *handler, ...)
	CODE:
		static char funcName[] =  "Triceps::AggregatorType::new";
		clearErrMsg();

		RowType *rt = wrt->get();

		Onceref<PerlCallback> cbconst; // defaults to NULL
		if (SvOK(constructor)) {
			cbconst = new PerlCallback();
			PerlCallbackInitializeSplit(cbconst, "Triceps::AggregatorType::new(constructor)", constructor, 5, items-5);
			if (cbconst->code_ == NULL)
				XSRETURN_UNDEF; // error message is already set
		}

		Onceref<PerlCallback> cbhand = new PerlCallback();
		PerlCallbackInitialize(cbhand, "Triceps::AggregatorType::new(handler)", 4, items-4);
		if (cbhand->code_ == NULL)
			XSRETURN_UNDEF; // error message is already set

		RETVAL = new WrapAggregatorType(new PerlAggregatorType(name, rt, cbconst, cbhand));
	OUTPUT:
		RETVAL

# make an uninitialized copy
WrapAggregatorType *
copy(WrapAggregatorType *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::AggregatorType";

		clearErrMsg();
		PerlAggregatorType *agt = self->get();
		RETVAL = new WrapAggregatorType(static_cast<PerlAggregatorType *>( agt->copy() ));
	OUTPUT:
		RETVAL

int
same(WrapAggregatorType *self, WrapAggregatorType *other)
	CODE:
		clearErrMsg();
		PerlAggregatorType *agself = self->get();
		PerlAggregatorType *agother = other->get();
		RETVAL = (agself == agother);
	OUTPUT:
		RETVAL

# print(self, [ indent, [ subindent ] ])
#   indent - default "", undef means "print everything in a signle line"
#   subindent - default "  "
SV *
print(WrapAggregatorType *self, ...)
	PPCODE:
		GEN_PRINT_METHOD(PerlAggregatorType)

# type comparisons
int
equals(WrapAggregatorType *self, WrapAggregatorType *other)
	CODE:
		clearErrMsg();
		PerlAggregatorType *agself = self->get();
		PerlAggregatorType *agother = other->get();
		RETVAL = agself->equals(agother);
	OUTPUT:
		RETVAL

int
match(WrapAggregatorType *self, WrapAggregatorType *other)
	CODE:
		clearErrMsg();
		PerlAggregatorType *agself = self->get();
		PerlAggregatorType *agother = other->get();
		RETVAL = agself->match(agother);
	OUTPUT:
		RETVAL

