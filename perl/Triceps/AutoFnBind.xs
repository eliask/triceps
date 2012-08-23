//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for MultiFnBind (yes, a different name in Perl!).

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "TricepsOpt.h"

MODULE = Triceps::AutoFnBind		PACKAGE = Triceps::AutoFnBind
###################################################################################

void
DESTROY(WrapMultiFnBind *self)
	CODE:
		// warn("AutoFnBind destroyed!");
		delete self;

# A scoped binding for multiple FnReturns.
# The FnReturns and FnBindings go in pairs.
#
# $ab = AutoFnBind->new($ret1 => $binding1, ...)
WrapMultiFnBind *
new(char *CLASS, ...)
	CODE:
		static char funcName[] =  "Triceps::AutoFnBind::new";
		clearErrMsg();
		Autoref<MultiFnBind> mb = new MultiFnBind;
		try {
			if (items % 2 != 1) {
				throw Exception("Usage: Triceps::AutoFnBind::new(CLASS, ret1 => binding1, ...), FnReturn and FnBinding objects must go in pairs", false);
			}
			for (int i = 1; i < items; i += 2) {
				FnReturn *ret = TRICEPS_GET_WRAP(FnReturn, ST(i), "%s: argument %d", funcName, i)->get();
				FnBinding *bind = TRICEPS_GET_WRAP(FnBinding, ST(i+1), "%s: argument %d", funcName, i+1)->get();
				
				if (!ret->getType()->match(bind->getType())) {
					throw Exception(strprintf("%s: Attempted to push a mismatching binding on the FnReturn '%s'.", 
						funcName, ret->getName().c_str()), true);
				}

				try {
					mb->add(ret, bind);
				} catch (Exception e) {
					throw Exception(e, strprintf("%s: invalid arguments:", funcName));
				}
			}
		} TRICEPS_CATCH_CROAK;

		RETVAL = new WrapMultiFnBind(mb);
	OUTPUT:
		RETVAL

