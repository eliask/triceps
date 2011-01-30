#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "const-c.inc"

#include <string.h>
#include <wrap/Wrap.h>
#include <common/Strprintf.h>
#include <mem/EasyBuffer.h>

using namespace Biceps;

static void clearErrMsg()
{
	SV *errsv = get_sv("!", 0);
	if (errsv) {
		sv_setpvn(errsv, "", 0);
	}
}

static void setErrMsg(const std::string &msg)
{
	// chop the trailing \n if present
	int  len = msg.size();
	if (!msg.empty() && msg[msg.size()-1] == '\n')
		len--;

	SV *errsv = get_sv("!", 0);
	if (errsv) {
		sv_setpvn(errsv, msg.c_str(), len);
	} else {
		warn("Biceps: can not set $! with error: %s", msg.c_str());
	}
}

// Copy a Perl scalar (numeric) SV value into a memory buffer.
// @param ti - field type selection
// @param val - SV to copy from
// @param bytes - memory buffer to copy to, must be large enough
// @return - true if set OK, false if value was non-numeric
static bool svToBytes(Type::TypeId ti, SV *val, char *bytes)
{
	IV xiv;
	int64_t x64;
	int32_t x32;
	double xfv;

	// This check is NOT a good idea, it disables the automatic conversions from strings.
	// Without it the unit test complains when the string doesn't contain a number,
	// but it's a lesser evil.
	// if (!SvNOK(val) && !SvIOK(val)) return false;

	switch(ti) {
	case Type::TT_INT32:
		x32 = SvIV(val);
		memcpy(bytes, &x32, sizeof(x32));
		break;
	case Type::TT_INT64:
		if (sizeof(xiv) == sizeof(x64)) { // 64-bit machine, copy directly
			x64 = SvIV(val);
		} else { // 32-bit machine, int64 represented in Perl as double
			x64 = SvNV(val);
		}
		memcpy(bytes, &x64, sizeof(x64));
		break;
	case Type::TT_FLOAT64:
		xfv = SvNV(val);
		memcpy(bytes, &xfv, sizeof(xfv));
		break;
	default:
		croak("Biceps svToBytes called with unsupported type %d\n", ti);
		break;
	}
	return true;
}

// Convert a Perl value (scalar or list) to a buffer
// with raw bytes suitable for setting into a record.
// Does NOT check for undef, the caller must do that before.
// Also silently allows to set the arrays for the scalar fields
// and scalars into arrays.
// 
// @param ti - field type selection
// @param arg - value to post to, must be already checked for SvOK
// @param fname - field name, for error messages
// @return - new buffer (with size_ set), or NULL (then with error set)
static EasyBuffer * valToBuf(Type::TypeId ti, SV *arg, const char *fname)
{
	EasyBuffer *buf = NULL;
	STRLEN slen;
	char *xsv;

	// as a special case, strings and utint8 can not be arrays, they're always Perl strings
	switch(ti) {
	case Type::TT_UINT8:
	case Type::TT_STRING:
		if (SvROK(arg)) {
			setErrMsg(strprintf("Biceps field '%s' data conversion: array reference may not be used for string and uint8", fname));
			return NULL;
		}
		if (ti == Type::TT_UINT8) {
			xsv = SvPV(arg, slen);
			buf = new(slen) EasyBuffer;
			memcpy(buf->data_, xsv, slen);
			buf->size_ = slen;
		} else { // Type::TT_STRING
			// make sure that the string is 0-terminated
			xsv = SvPV(arg, slen);
			buf = new(slen+1) EasyBuffer;
			memcpy(buf->data_, xsv, slen);
			buf->data_[slen] = 0;
			buf->size_ = slen+1;
		}
		return buf;
		break;

	case Type::TT_INT32:
		slen = sizeof(int32_t);
		break;
	case Type::TT_INT64:
		slen = sizeof(int64_t);
		break;
	case Type::TT_FLOAT64:
		slen = sizeof(double);
		break;
	default:
		setErrMsg(strprintf("Biceps field '%s' data conversion: invalid field type???", fname));
		return NULL;
		break;
	}

	// by now it's known to be a numeric type, with value size in slen

	if (SvROK(arg)) {
		AV *lst = (AV *)SvRV(arg);
		if (SvTYPE(lst) != SVt_PVAV) {
			setErrMsg(strprintf("Biceps field '%s' data conversion: reference not to an array", fname));
			return NULL;
		}
		int llen = av_len(lst)+1; // it's the Perl $#array, so add 1

		// fprintf(stderr, "Setting an array into field '%s', size %d\n", fname, llen);
		
		buf = new(slen*llen) EasyBuffer;
		buf->size_ = slen*llen;
		xsv = buf->data_;
		for (int i = 0; i < llen; i++, xsv += slen) {
			if (!svToBytes(ti, *av_fetch(lst, i, 0),  xsv)) {
				delete buf;
				setErrMsg(strprintf("Biceps field '%s' element %d data conversion: non-numeric value", fname, i));
				return NULL;
			}
		}
	} else {
		buf = new(slen) EasyBuffer;
		buf->size_ = slen;
		if (!svToBytes(ti, arg,  buf->data_)) {
			delete buf;
			setErrMsg(strprintf("Biceps field '%s' data conversion: non-numeric value", fname));
			return NULL;
		}
	}
	return buf;
}

// Convert a byte buffer from a row to a Perl value.
// @param ti - id of the simple type
// @param arsz - array size, affects the resulting value:
//        Type::AR_SCALAR - returns a scalar
//        anything else - returns an array reference
//        (except that TT_STRING and TT_UINT8 are always returned as Perl scalar strings)
// @param notNull - if false, returns an undef (suiitable for putting in an array)
// @param data - the raw data buffer
// @param dlen - data buffer length
// @param fname - field name, for error messages
// @return - a new SV
SV *bytesToVal(Type::TypeId ti, int arsz, bool notNull, const char *data, intptr_t dlen, const char *fname)
{
	int64_t x64;
	int32_t x32;
	double xfv;

	if (!notNull)
		return newSV(0); // undef value

	if (arsz < 0 || ti == Type::TT_STRING || ti == Type::TT_UINT8) { //  Type::AR_SCALAR
		switch(ti) {
		case Type::TT_UINT8:
			return newSVpvn(data, dlen);
			break;
		case Type::TT_STRING:
			// a string normally has a zero byte at the end, deduct that
			if (dlen > 0 && data[dlen-1] == 0)
				--dlen;
			return newSVpvn(data, dlen);
			break;
		case Type::TT_INT32:
			if ((size_t)dlen >= sizeof(x32))  {
				memcpy(&x32, data, sizeof(x32));
				return newSViv(x32);
			}
			break;
		case Type::TT_INT64:
			if ((size_t)dlen >= sizeof(x64))  {
				memcpy(&x64, data, sizeof(x64));
				if (sizeof(IV) == sizeof(x64)) { // 64-bit machine, copy directly
					return newSViv(x64);
				} else { // 32-bit machine, int64 represented in Perl as double
					return newSVnv(x64);
				}
			}
			break;
		case Type::TT_FLOAT64:
			if ((size_t)dlen >= sizeof(xfv))  {
				memcpy(&xfv, data, sizeof(xfv));
				return newSVnv(xfv);
			}
			break;
		default:
			warn("Biceps field '%s' data conversion: invalid field type???", fname);
			break;
		}
	} else {
		AV *lst = newAV();
		switch(ti) {
		case Type::TT_INT32:
			while ((size_t)dlen >= sizeof(x32))  {
				memcpy(&x32, data, sizeof(x32));
				av_push(lst, newSViv(x32));
				data += sizeof(x32); dlen -= sizeof(x32);
			}
			break;
		case Type::TT_INT64:
			while ((size_t)dlen >= sizeof(x64))  {
				memcpy(&x64, data, sizeof(x64));
				if (sizeof(IV) == sizeof(x64)) { // 64-bit machine, copy directly
					av_push(lst, newSViv(x64));
				} else { // 32-bit machine, int64 represented in Perl as double
					av_push(lst, newSVnv(x64));
				}
				data += sizeof(x64); dlen -= sizeof(x64);
			}
			break;
		case Type::TT_FLOAT64:
			while ((size_t)dlen >= sizeof(xfv))  {
				memcpy(&xfv, data, sizeof(xfv));
				av_push(lst, newSVnv(xfv));
				data += sizeof(xfv); dlen -= sizeof(xfv);
			}
			break;
		default:
			warn("Biceps field '%s' data conversion: invalid field type???", fname);
			break;
		}
		return newRV_noinc((SV *)lst); 
	}
	return newSV(0); // undef value
}

MODULE = Biceps		PACKAGE = Biceps

INCLUDE: const-xs.inc

###################################################################################
MODULE = Biceps		PACKAGE = Biceps::RowType

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
		RowType *rt = self->t_;

		const RowType::FieldVec &fld = rt->fields();
		int nf = fld.size();
		for (int i = 0; i < nf; i++) {
			PUSHs(sv_2mortal(newSVpvn(fld[i].name_.c_str(), fld[i].name_.size())));
			string t = fld[i].type_->print();
			if (fld[i].arsz_ >= 0)
				t.append("[]");
			PUSHs(sv_2mortal(newSVpvn(t.c_str(), t.size())));
		}


# the row factory, from a hash-style name-value list
WrapRow *
makerow_hs(WrapRowType *self, ...)
	CODE:
		clearErrMsg();
		RowType *rt = self->t_;
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

# the row factory, from an array of values in the exact order (lice CSV files),
# filling the missing values at the end with nulls
WrapRow *
makerow_ar(WrapRowType *self, ...)
	CODE:
		clearErrMsg();
		RowType *rt = self->t_;
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

###################################################################################
MODULE = Biceps		PACKAGE = Biceps::Row

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
		RowType *t = self->r_.getType();
		Row *r = self->r_.get();
		t->hexdumpRow(dump, r);
		RETVAL = (char *)dump.c_str();
	OUTPUT:
		RETVAL

# convert to an array of name-value pairs, suitable for setting into a hash
SV *
to_hs(WrapRow *self)
	PPCODE:
		clearErrMsg();
		RowType *t = self->r_.getType();
		Row *r = self->r_.get();
		const RowType::FieldVec &fld = t->fields();
		int nf = fld.size();

		for (int i = 0; i < nf; i++) {
			PUSHs(sv_2mortal(newSVpvn(fld[i].name_.c_str(), fld[i].name_.size())));
			
			const char *data;
			intptr_t dlen;
			bool notNull = t->getField(r, i, data, dlen);
			PUSHs(sv_2mortal(bytesToVal(fld[i].type_->getTypeId(), fld[i].arsz_, notNull, data, dlen, fld[i].name_.c_str())));
		}

# convert to an array of data values, like CSV
SV *
to_ar(WrapRow *self)
	PPCODE:
		clearErrMsg();
		RowType *t = self->r_.getType();
		Row *r = self->r_.get();
		const RowType::FieldVec &fld = t->fields();
		int nf = fld.size();

		for (int i = 0; i < nf; i++) {
			const char *data;
			intptr_t dlen;
			bool notNull = t->getField(r, i, data, dlen);
			PUSHs(sv_2mortal(bytesToVal(fld[i].type_->getTypeId(), fld[i].arsz_, notNull, data, dlen, fld[i].name_.c_str())));
		}
