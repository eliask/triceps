//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for TableType.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "BicepsPerl.h"

MODULE = Biceps::TableType		PACKAGE = Biceps::TableType
###################################################################################

void
DESTROY(WrapTableType *self)
	CODE:
		// warn("TableType destroyed!");
		delete self;

WrapTableType *
Biceps::TableType::new(WrapRowType *wrt)
	CODE:
		clearErrMsg();

		RETVAL = new WrapTableType(new TableType(wrt->get()));
	OUTPUT:
		RETVAL

# XXX add copy()?

# print the description
# XXX add indenting?
SV *
print(WrapTableType *self)
	PPCODE:
		clearErrMsg();
		TableType *tbt = self->get();
		string res;
		tbt->printTo(res);
		PUSHs(sv_2mortal(newSVpvn(res.c_str(), res.size())));

# type comparisons
int
equals(WrapTableType *self, WrapTableType *other)
	CODE:
		clearErrMsg();
		TableType *tbself = self->get();
		TableType *tbother = other->get();
		RETVAL = tbself->equals(tbother);
	OUTPUT:
		RETVAL

int
match(WrapTableType *self, WrapTableType *other)
	CODE:
		clearErrMsg();
		TableType *tbself = self->get();
		TableType *tbother = other->get();
		RETVAL = tbself->match(tbother);
	OUTPUT:
		RETVAL

int
same(WrapTableType *self, WrapTableType *other)
	CODE:
		clearErrMsg();
		TableType *tbself = self->get();
		TableType *tbother = other->get();
		RETVAL = (tbself == tbother);
	OUTPUT:
		RETVAL

# add an index
WrapTableType *
addIndex(WrapTableType *self, char *subname, WrapIndexType *sub)
	CODE:
		char funcName[] = "Biceps::TableType::addIndex";
		// for casting of return value
		static char CLASS[] = "Biceps::TableType";

		clearErrMsg();
		TableType *tbt = self->get();

		if (tbt->isInitialized()) {
			setErrMsg(strprintf("%s: table is already initialized, can not add indexes any more", funcName));
			XSRETURN_UNDEF;
		}

		IndexType *ixsub = sub->get();
		// can't just return self because it will upset the refcount
		RETVAL = new WrapTableType(tbt->addIndex(subname, ixsub));
	OUTPUT:
		RETVAL

# find a nested index by name
WrapIndexType *
findIndex(WrapTableType *self, char *subname)
	CODE:
		char funcName[] = "Biceps::TableType::findIndex";
		// for casting of return value
		static char CLASS[] = "Biceps::IndexType";

		clearErrMsg();
		TableType *tbt = self->get();
		IndexType *ixsub = tbt->findIndex(subname);
		if (ixsub == NULL) {
			setErrMsg(strprintf("%s: unknown nested index '%s'", funcName, subname));
			XSRETURN_UNDEF;
		}
		RETVAL = new WrapIndexType(ixsub);
	OUTPUT:
		RETVAL

# get the first leaf sub-index
WrapIndexType *
firstLeafIndex(WrapTableType *self)
	CODE:
		char funcName[] = "Biceps::TableType::firstLeafIndex";
		// for casting of return value
		static char CLASS[] = "Biceps::IndexType";

		clearErrMsg();
		TableType *tbt = self->get();
		IndexType *leaf = tbt->firstLeafIndex();
		if (leaf == NULL) {
			setErrMsg(strprintf("%s: table type has no indexes defined", funcName));
			XSRETURN_UNDEF;
		}
		RETVAL = new WrapIndexType(leaf);
	OUTPUT:
		RETVAL

# XXX dealing with IndexId requires constants, so leave a lone for now...

# check if the type has been initialized
int
isInitialized(WrapTableType *self)
	CODE:
		clearErrMsg();
		TableType *tbt = self->get();
		RETVAL = tbt->isInitialized();
	OUTPUT:
		RETVAL

# initialize, returns 1 on success, undef on error
int
initialize(WrapTableType *self)
	CODE:
		clearErrMsg();
		TableType *tbt = self->get();
		tbt->initialize();
		Erref err = tbt->getErrors();
		if (err->hasError()) {
			setErrMsg(err->print());
			XSRETURN_UNDEF;
		}
		RETVAL = 1;
	OUTPUT:
		RETVAL

# get back the row type
WrapRowType *
rowType(WrapTableType *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Biceps::RowType";

		clearErrMsg();
		TableType *tbt = self->get();
		RETVAL = new WrapRowType(const_cast<RowType *>(tbt->rowType()));
	OUTPUT:
		RETVAL

