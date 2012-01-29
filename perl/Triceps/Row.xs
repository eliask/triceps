//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Row.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

MODULE = Triceps::Row		PACKAGE = Triceps::Row
###################################################################################

BOOT:
// fprintf(stderr, "DEBUG Row items=%d sp=%p mark=%p\n", items, sp, mark);

void
DESTROY(WrapRow *self)
	CODE:
		// warn("Row destroyed!");
		delete self;

# for debugging, make a hex dump
char *
hexdump(WrapRow *self)
	CODE:
		clearErrMsg();
		string dump;
		const RowType *t = self->ref_.getType();
		Row *r = self->ref_.get();
		t->hexdumpRow(dump, r);
		RETVAL = (char *)dump.c_str();
	OUTPUT:
		RETVAL

# convert to an array of name-value pairs, suitable for setting into a hash
SV *
toHash(WrapRow *self)
	PPCODE:
		clearErrMsg();
		const RowType *t = self->ref_.getType();
		Row *r = self->ref_.get();
		const RowType::FieldVec &fld = t->fields();
		int nf = fld.size();

		for (int i = 0; i < nf; i++) {
			XPUSHs(sv_2mortal(newSVpvn(fld[i].name_.c_str(), fld[i].name_.size())));
			
			const char *data;
			intptr_t dlen;
			bool notNull = t->getField(r, i, data, dlen);
			XPUSHs(sv_2mortal(bytesToVal(fld[i].type_->getTypeId(), fld[i].arsz_, notNull, data, dlen, fld[i].name_.c_str())));
		}

# convert to an array of data values, like CSV
SV *
toArray(WrapRow *self)
	PPCODE:
		clearErrMsg();
		const RowType *t = self->ref_.getType();
		Row *r = self->ref_.get();
		const RowType::FieldVec &fld = t->fields();
		int nf = fld.size();

		for (int i = 0; i < nf; i++) {
			const char *data;
			intptr_t dlen;
			bool notNull = t->getField(r, i, data, dlen);
			XPUSHs(sv_2mortal(bytesToVal(fld[i].type_->getTypeId(), fld[i].arsz_, notNull, data, dlen, fld[i].name_.c_str())));
		}

# copy the row and modify the specified fields when copying
WrapRow *
copymod(WrapRow *self, ...)
	CODE:
		clearErrMsg();
		const RowType *rt = self->ref_.getType();
		Row *r = self->ref_.get();

		// for casting of return value
		static char CLASS[] = "Triceps::Row";

		// The arguments come in pairs fieldName => value;
		// the value may be either a simple value that will be
		// cast to the right type, or a reference to a list of values.
		// The uint8 and string are converted from Perl strings
		// (the difference for now is that string is 0-terminated)
		// and can not have lists.

		if (items % 2 != 1) {
			setErrMsg("Usage: Triceps::Row::copymod(RowType, [fieldName, fieldValue, ...]), names and types must go in pairs");
			XSRETURN_UNDEF;
		}

		// parse data to create a copy
		FdataVec fields;
		rt->splitInto(r, fields);

		// now override the modified fields
		// this code is copied from RowType::makerow_hs
		vector<Autoref<EasyBuffer> > bufs;
		for (int i = 1; i < items; i += 2) {
			const char *fname = (const char *)SvPV_nolen(ST(i));
			int idx  = rt->findIdx(fname);
			if (idx < 0) {
				setErrMsg(strprintf("%s: attempting to set an unknown field '%s'", "Triceps::Row::copymod", fname));
				XSRETURN_UNDEF;
			}
			const RowType::Field &finfo = rt->fields()[idx];

			if (!SvOK(ST(i+1))) { // undef translates to null
				fields[idx].setNull();
			} else {
				if (SvROK(ST(i+1)) && finfo.arsz_ < 0) {
					setErrMsg(strprintf("%s: attempting to set an array into scalar field '%s'", "Triceps::Row::copymod", fname));
					XSRETURN_UNDEF;
				}
				EasyBuffer *d = valToBuf(finfo.type_->getTypeId(), ST(i+1), fname);
				if (d == NULL)
					XSRETURN_UNDEF; // error message already set
				bufs.push_back(d); // remember for cleaning

				fields[idx].setPtr(true, d->data_, d->size_);
			}
		}
		RETVAL = new WrapRow(rt, rt->makeRow(fields));
	OUTPUT:
		RETVAL

# get the value of one field by name
SV *
get(WrapRow *self, char *fname)
	PPCODE:
		clearErrMsg();
		const RowType *t = self->ref_.getType();
		Row *r = self->ref_.get();
		const RowType::FieldVec &fld = t->fields();

		int i = t->findIdx(fname);
		if ( i < 0 ) {
			setErrMsg(strprintf("%s: unknown field '%s'", "Triceps::Row::get", fname));
			XSRETURN_UNDEF;
		}

		const char *data;
		intptr_t dlen;
		bool notNull = t->getField(r, i, data, dlen);
		XPUSHs(sv_2mortal(bytesToVal(fld[i].type_->getTypeId(), fld[i].arsz_, notNull, data, dlen, fld[i].name_.c_str())));

# get the type of the row
WrapRowType*
getType(WrapRow *self)
	CODE:
		clearErrMsg();
		const RowType *t = self->ref_.getType();

		// for casting of return value
		static char CLASS[] = "Triceps::RowType";
		RETVAL = new WrapRowType(const_cast<RowType *>(t));
	OUTPUT:
		RETVAL

# check whether both refs point to the same object
int
same(WrapRow *self, WrapRow *other)
	CODE:
		clearErrMsg();
		Row *r1 = self->get();
		Row *r2 = other->get();
		RETVAL = (r1 == r2);
	OUTPUT:
		RETVAL

