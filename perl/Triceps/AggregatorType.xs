//
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


# XXX should wrt and name change places?
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
		static char funcName[] =  "Triceps::IndexType::newHashed";
		clearErrMsg();

		RowType *rt = wrt->get();

		Onceref<PerlCallback> cbconst; // defaults to NULL
		if (SvOK(constructor)) {
			cbconst = new PerlCallback();
			PerlCallbackInitializeSplit(cbconst, funcName, constructor, 5, items-5);
			if (cbconst->code_ == NULL)
				XSRETURN_UNDEF; // error message is already set
		}

		Onceref<PerlCallback> cbhand = new PerlCallback();
		PerlCallbackInitialize(cbhand, funcName, 4, items-4);
		if (cbhand->code_ == NULL)
			XSRETURN_UNDEF; // error message is already set

		RETVAL = new WrapAggregatorType(new PerlAggregatorType(name, rt, cbconst, cbhand));
	OUTPUT:
		RETVAL
