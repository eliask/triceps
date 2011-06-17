//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Table.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

MODULE = Triceps::Table		PACKAGE = Triceps::Table
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
		// for casting of return value
		static char CLASS[] = "Triceps::Label";

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
		// for casting of return value
		static char CLASS[] = "Triceps::Label";

		clearErrMsg();
		Table *t = self->get();
		RETVAL = new WrapLabel(t->getLabel());
	OUTPUT:
		RETVAL

WrapTableType *
getType(WrapTable *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::TableType";

		clearErrMsg();
		Table *t = self->get();
		RETVAL = new WrapTableType(const_cast<TableType *>(t->getType()));
	OUTPUT:
		RETVAL

WrapUnit*
getUnit(WrapTable *self)
	CODE:
		clearErrMsg();
		Table *tab = self->get();

		// for casting of return value
		static char CLASS[] = "Triceps::Unit";
		RETVAL = new WrapUnit(tab->getUnit());
	OUTPUT:
		RETVAL

# XXX test the methods below

# check whether both refs point to the same type object
int
same(WrapTable *self, WrapTable *other)
	CODE:
		clearErrMsg();
		Table *t = self->get();
		Table *ot = other->get();
		RETVAL = (t == ot);
	OUTPUT:
		RETVAL

WrapRowType *
getRowType(WrapTable *self)
	CODE:
		clearErrMsg();
		Table *tab = self->get();

		// for casting of return value
		static char CLASS[] = "Triceps::RowType";
		RETVAL = new WrapRowType(const_cast<RowType *>(tab->getRowType()));
	OUTPUT:
		RETVAL

char *
getName(WrapTable *self)
	CODE:
		clearErrMsg();
		Table *t = self->get();
		RETVAL = (char *)t->getName().c_str();
	OUTPUT:
		RETVAL

# this may be 64-bit, and IV is guaranteed to be pointer-sized
IV
size(WrapTable *self)
	CODE:
		clearErrMsg();
		Table *t = self->get();
		RETVAL = t->size();
	OUTPUT:
		RETVAL

#WrapRowHandle *
#makeRowHandle(WrapTable *self, WrapRow *row)

# XXX add the rest of methods

