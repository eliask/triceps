//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Table.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "BicepsPerl.h"

MODULE = Biceps::Table		PACKAGE = Biceps::Table
###################################################################################

void
DESTROY(WrapTable *self)
	CODE:
		// warn("Table destroyed!");
		delete self;


# The table gets created by Unit::makeTable

WrapLabel *
getInputLabel(WrapTable *self)
	CODE:
		char funcName[] = "Biceps::Table::getInputLabel";
		// for casting of return value
		static char CLASS[] = "Biceps::Label";

		clearErrMsg();
		Table *t = self->get();
		RETVAL = new WrapLabel(t->getInputLabel());
	OUTPUT:
		RETVAL

# since the C++ inheritance doesn't propagate to Perl, the inherited call getLabel()
# becomes an explicit getOutputLabel()
WrapLabel *
getOutputLabel(WrapTable *self)
	CODE:
		char funcName[] = "Biceps::Table::getOutputLabel";
		// for casting of return value
		static char CLASS[] = "Biceps::Label";

		clearErrMsg();
		Table *t = self->get();
		RETVAL = new WrapLabel(t->getLabel());
	OUTPUT:
		RETVAL

# XXX add the rest of methods
