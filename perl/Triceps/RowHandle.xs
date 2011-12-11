//
// (C) Copyright 2011 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for RowHandle.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

MODULE = Triceps::RowHandle		PACKAGE = Triceps::RowHandle
###################################################################################

void
DESTROY(WrapRowHandle *self)
	CODE:
		// warn("RowHandle destroyed!");
		delete self;

# check whether both refs point to the same object
int
same(WrapRowHandle *self, WrapRowHandle *other)
	CODE:
		clearErrMsg();
		RowHandle *r1 = self->get();
		RowHandle *r2 = other->get();
		RETVAL = (r1 == r2);
	OUTPUT:
		RETVAL

# A special thing about WrapRowHandles is that for the convenience of comparing
# iterators, they may contain the NULL pointers. So wherever they are used, must
# check for NULL.

WrapRow *
getRow(WrapRowHandle *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::Row";
		clearErrMsg();
		RowHandle *rh = self->get();

		if (rh == NULL) {
			setErrMsg("Triceps::RowHandle::getRow: RowHandle is NULL");
			XSRETURN_UNDEF;
		}

		// XXX Should it check for row being NULL? C++ code can create that...
		RETVAL = new WrapRow(const_cast<RowType *>(self->ref_.getTable()->getRowType()), const_cast<Row *>(rh->getRow()));
	OUTPUT:
		RETVAL

int
isInTable(WrapRowHandle *self)
	CODE:
		clearErrMsg();
		RowHandle *rh = self->get();

		if (rh == NULL) {
			setErrMsg("Triceps::RowHandle::isInTable: RowHandle is NULL");
			XSRETURN_UNDEF;
		}

		RETVAL = rh->isInTable();
	OUTPUT:
		RETVAL

# check for NULL, which means the end() iterator
int
isNull(WrapRowHandle *self)
	CODE:
		clearErrMsg();
		RowHandle *rh = self->get();
		RETVAL = (rh == NULL);
	OUTPUT:
		RETVAL

# tested in Table.t
