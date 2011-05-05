//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for RowType.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "BicepsPerl.h"

MODULE = Biceps::RowType		PACKAGE = Biceps::RowType
###################################################################################

BOOT:
// fprintf(stderr, "DEBUG RowType items=%d sp=%p mark=%p\n", items, sp, mark);

WrapRowType *
Biceps::RowType::new(...)
	CODE:
		RowType::FieldVec fld;
		RowType::Field add;

		clearErrMsg();
		if (items < 3 || items % 2 != 1) {
			setErrMsg("Usage: Biceps::RowType::new(CLASS, fieldName, fieldType, ...), names and types must go in pairs");
			XSRETURN_UNDEF;
		}
		for (int i = 1; i < items; i += 2) {
			const char *fname = (const char *)SvPV_nolen(ST(i));
			STRLEN ftlen;
			char *ftype = (char *)SvPV(ST(i+1), ftlen);
			if (ftlen >= 2 && ftype[ftlen-1] == ']' && ftype[ftlen-2] == '[') {
				ftype[ftlen-2] = 0;
				add.assign(fname, Type::findSimpleType(ftype), RowType::Field::AR_VARIABLE);
				ftype[ftlen-2] = '[';
			} else {
				add.assign(fname, Type::findSimpleType(ftype));
			}
			if (add.type_.isNull()) {
				setErrMsg(strprintf("%s: field '%s' has an unknown type '%s'", "Biceps::RowType::new", fname, ftype));
				XSRETURN_UNDEF;
			}
			if (add.arsz_ != RowType::Field::AR_SCALAR && add.type_->getTypeId() == Type::TT_STRING) {
				setErrMsg(strprintf("%s: field '%s' string array type is not supported", "Biceps::RowType::new", fname));
				XSRETURN_UNDEF;
			}
			fld.push_back(add);
		}
		Onceref<RowType> rt = new CompactRowType(fld);
		Erref err = rt->getErrors();
		if (!err.isNull() && !err->isEmpty()) {
			setErrMsg("Biceps::RowType::new: " + err->print());
			XSRETURN_UNDEF;
		}

		RETVAL = new WrapRowType(rt);
	OUTPUT:
		RETVAL

void
DESTROY(WrapRowType *self)
	CODE:
		// warn("RowType destroyed!");
		delete self;

# get back the type definition
SV *
getdef(WrapRowType *self)
	PPCODE:
		clearErrMsg();
		RowType *rt = self->get();

		const RowType::FieldVec &fld = rt->fields();
		int nf = fld.size();
		for (int i = 0; i < nf; i++) {
			XPUSHs(sv_2mortal(newSVpvn(fld[i].name_.c_str(), fld[i].name_.size())));
			string t = fld[i].type_->print();
			if (fld[i].arsz_ >= 0)
				t.append("[]");
			XPUSHs(sv_2mortal(newSVpvn(t.c_str(), t.size())));
		}


# the row factory, from a hash-style name-value list
WrapRow *
makerow_hs(WrapRowType *self, ...)
	CODE:
		clearErrMsg();
		RowType *rt = self->get();
		// for casting of return value
		static char CLASS[] = "Biceps::Row";

		// The arguments come in pairs fieldName => value;
		// the value may be either a simple value that will be
		// cast to the right type, or a reference to a list of values.
		// The uint8 and string are converted from Perl strings
		// (the difference for now is that string is 0-terminated)
		// and can not have lists.

		if (items % 2 != 1) {
			setErrMsg("Usage: Biceps::RowType::makerow_hs(RowType, fieldName, fieldValue, ...), names and types must go in pairs");
			XSRETURN_UNDEF;
		}

		int nf = rt->fieldCount();
		FdataVec fields(nf);
		for (int i = 0; i < nf; i++) {
			fields[i].setNull(); // default the fields to null
		}
		vector<Autoref<EasyBuffer> > bufs;
		for (int i = 1; i < items; i += 2) {
			const char *fname = (const char *)SvPV_nolen(ST(i));
			int idx  = rt->findIdx(fname);
			if (idx < 0) {
				setErrMsg(strprintf("%s: attempting to set an unknown field '%s'", "Biceps::RowType::makerow_hs", fname));
				XSRETURN_UNDEF;
			}
			const RowType::Field &finfo = rt->fields()[idx];

			if (!SvOK(ST(i+1))) { // undef translates to null
				fields[idx].setNull();
			} else {
				if (SvROK(ST(i+1)) && finfo.arsz_ < 0) {
					setErrMsg(strprintf("%s: attempting to set an array into scalar field '%s'", "Biceps::RowType::makerow_hs", fname));
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

# the row factory, from an array of values in the exact order (like CSV files),
# filling the missing values at the end with nulls
WrapRow *
makerow_ar(WrapRowType *self, ...)
	CODE:
		clearErrMsg();
		RowType *rt = self->get();
		// for casting of return value
		static char CLASS[] = "Biceps::Row";

		int nf = rt->fieldCount();

		if (items > nf + 1) {
			setErrMsg(strprintf("Biceps::RowType::makerow_ar: %d args, only %d fields in ", items-1, nf) + rt->print(NOINDENT));
			XSRETURN_UNDEF;
		}

		FdataVec fields(nf);
		for (int i = 0; i < nf; i++) {
			fields[i].setNull(); // default the fields to null
		}
		vector<Autoref<EasyBuffer> > bufs;
		for (int i = 1; i < items; i ++) {
			const RowType::Field &finfo = rt->fields()[i-1];
			const char *fname = finfo.name_.c_str();

			if (SvOK(ST(i))) { // undef translates to null, which is already set
				if (SvROK(ST(i)) && finfo.arsz_ < 0) {
					setErrMsg(strprintf("%s: attempting to set an array into scalar field '%s'", "Biceps::RowType::makerow_ar", fname));
					XSRETURN_UNDEF;
				}
				EasyBuffer *d = valToBuf(finfo.type_->getTypeId(), ST(i), fname);
				if (d == NULL)
					XSRETURN_UNDEF; // error message already set
				bufs.push_back(d); // remember for cleaning

				fields[i-1].setPtr(true, d->data_, d->size_);
			}
		}
		RETVAL = new WrapRow(rt, rt->makeRow(fields));
	OUTPUT:
		RETVAL


# XXX add print(), equals(), match()
