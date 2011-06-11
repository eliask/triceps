//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for TableType.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

MODULE = Triceps::TableType		PACKAGE = Triceps::TableType
###################################################################################

void
DESTROY(WrapTableType *self)
	CODE:
		// warn("TableType destroyed!");
		delete self;

WrapTableType *
Triceps::TableType::new(WrapRowType *wrt)
	CODE:
		clearErrMsg();

		RETVAL = new WrapTableType(new TableType(wrt->get()));
	OUTPUT:
		RETVAL

# XXX add copy()?

# print(self, [ indent, [ subindent ] ])
#   indent - default "", undef means "print everything in a signle line"
#   subindent - default "  "
SV *
print(WrapTableType *self, ...)
	PPCODE:
		GEN_PRINT_METHOD(TableType)

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
# XXX accept multiple subname-sub pairs as arguments
WrapTableType *
addSubIndex(WrapTableType *self, char *subname, WrapIndexType *sub)
	CODE:
		static char funcName[] =  "Triceps::TableType::addSubIndex";
		// for casting of return value
		static char CLASS[] = "Triceps::TableType";

		clearErrMsg();
		TableType *tbt = self->get();

		if (tbt->isInitialized()) {
			setErrMsg(strprintf("%s: table is already initialized, can not add indexes any more", funcName));
			XSRETURN_UNDEF;
		}

		IndexType *ixsub = sub->get();
		// can't just return self because it will upset the refcount
		RETVAL = new WrapTableType(tbt->addSubIndex(subname, ixsub));
	OUTPUT:
		RETVAL

# find a nested index by name
WrapIndexType *
findSubIndex(WrapTableType *self, char *subname)
	CODE:
		static char funcName[] =  "Triceps::TableType::findSubIndex";
		// for casting of return value
		static char CLASS[] = "Triceps::IndexType";

		clearErrMsg();
		TableType *tbt = self->get();
		IndexType *ixsub = tbt->findSubIndex(subname);
		if (ixsub == NULL) {
			setErrMsg(strprintf("%s: unknown nested index '%s'", funcName, subname));
			XSRETURN_UNDEF;
		}
		RETVAL = new WrapIndexType(ixsub);
	OUTPUT:
		RETVAL

# find a nested index by type id
WrapIndexType *
findSubIndexById(WrapTableType *self, SV *idarg)
	CODE:
		static char funcName[] =  "Triceps::TableType::findSubIndexById";
		// for casting of return value
		static char CLASS[] = "Triceps::IndexType";

		clearErrMsg();
		TableType *tbt = self->get();

		IndexType::IndexId id;
		if (!parseIndexId(funcName, idarg, id))
			XSRETURN_UNDEF;

		IndexType *ixsub = tbt->findSubIndexById(id);
		if (ixsub == NULL) {
			setErrMsg(strprintf("%s: no nested index with type id '%s' (%d)", funcName, IndexType::indexIdString(id), id));
			XSRETURN_UNDEF;
		}
		RETVAL = new WrapIndexType(ixsub);
	OUTPUT:
		RETVAL

# get the first leaf sub-index
WrapIndexType *
getFirstLeaf(WrapTableType *self)
	CODE:
		static char funcName[] =  "Triceps::TableType::getFirstLeaf";
		// for casting of return value
		static char CLASS[] = "Triceps::IndexType";

		clearErrMsg();
		TableType *tbt = self->get();
		IndexType *leaf = tbt->getFirstLeaf();
		if (leaf == NULL) {
			setErrMsg(strprintf("%s: table type has no indexes defined", funcName));
			XSRETURN_UNDEF;
		}
		RETVAL = new WrapIndexType(leaf);
	OUTPUT:
		RETVAL

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
		static char CLASS[] = "Triceps::RowType";

		clearErrMsg();
		TableType *tbt = self->get();
		RETVAL = new WrapRowType(const_cast<RowType *>(tbt->rowType()));
	OUTPUT:
		RETVAL

