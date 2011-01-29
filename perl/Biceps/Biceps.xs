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

// Convert a Perl value (scalar or list) to a buffer
// with raw bytes suitable for setting into a record.
// @param ti - field type selection
// @param arg - value to post to, must be already checked for SvOK
// @param fname - field name, for error messages
// @return - new buffer (with size_ set), or NULL (then with error set)
static EasyBuffer * valToBuf(Type::TypeId ti, SV *arg, const char *fname)
{
	EasyBuffer *buf = NULL;
	IV xiv;
	int64_t x64;
	int32_t x32;
	double xfv;
	STRLEN slen;
	char *xsv;

	if (SvROK(arg)) {
		setErrMsg(strprintf("Biceps field '%s' data conversion: setting arrays is not supported yet", fname));
		return NULL;
	} else {
		switch(ti) {
		case Type::TT_UINT8:
			xsv = SvPV(arg, slen);
			buf = new(slen) EasyBuffer;
			memcpy(buf->data_, xsv, slen);
			buf->size_ = slen;
			break;
		case Type::TT_STRING:
			// make sure that the string is 0-terminated
			xsv = SvPV(arg, slen);
			buf = new(slen+1) EasyBuffer;
			memcpy(buf->data_, xsv, slen);
			buf->data_[slen] = 0;
			buf->size_ = slen+1;
			break;
		case Type::TT_INT32:
			x32 = SvIV(arg);
			buf = new(sizeof(x32)) EasyBuffer;
			memcpy(buf->data_, &x32, sizeof(x32));
			buf->size_ = sizeof(x32);
			break;
		case Type::TT_INT64:
			if (sizeof(xiv) == sizeof(x64)) { // 64-bit machine, copy directly
				x64 = SvIV(arg);
			} else { // 32-bit machine, int64 represented in Perl as double
				x64 = SvNV(arg);
			}
			buf = new(sizeof(x64)) EasyBuffer;
			memcpy(buf->data_, &x64, sizeof(x64));
			buf->size_ = sizeof(x64);
			break;
		case Type::TT_FLOAT64:
			xfv = SvNV(arg);
			buf = new(sizeof(xfv)) EasyBuffer;
			memcpy(buf->data_, &xfv, sizeof(xfv));
			buf->size_ = sizeof(xfv);
			break;
		default:
			setErrMsg(strprintf("Biceps field '%s' data conversion: invalid field type???", fname));
			return NULL;
			break;
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
SV *bufToVal(Type::TypeId ti, int arsz, bool notNull, const char *data, intptr_t dlen, const char *fname)
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
		warn("Biceps field '%s' data conversion: getting arrays is not supported yet", fname);
		return newSV(0); // undef value
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
			setErrMsg("Usage: Biceps::RowType::makerow(RowType, fieldName, fieldValue, ...), names and types must go in pairs");
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
				setErrMsg(strprintf("%s: attempting to set an unknown field '%s'", "Biceps::RowType::makerow", fname));
				XSRETURN_UNDEF;
			}
			const RowType::Field &finfo = rt->fields()[idx];

			if (!SvOK(ST(i+1))) { // undef translates to null
				fields[idx].setNull();
			} else {
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
		RowType *t = self->r_.getType();
		Row *r = self->r_.get();
		const RowType::FieldVec &fld = t->fields();
		int nf = fld.size();

		for (int i = 0; i < nf; i++) {
			PUSHs(sv_2mortal(newSVpvn(fld[i].name_.c_str(), fld[i].name_.size())));
			
			const char *data;
			intptr_t dlen;
			bool notNull = t->getField(r, i, data, dlen);
			PUSHs(sv_2mortal(bufToVal(fld[i].type_->getTypeId(), fld[i].arsz_, notNull, data, dlen, fld[i].name_.c_str())));
		}
