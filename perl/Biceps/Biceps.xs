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
			break;
		case Type::TT_STRING:
			// make sure that the string is 0-terminated
			xsv = SvPV(arg, slen);
			buf = new(slen+1) EasyBuffer;
			memcpy(buf->data_, xsv, slen);
			buf->data_[slen] = 0;
			break;
		case Type::TT_INT32:
			x32 = SvIV(arg);
			buf = new(sizeof(x32)) EasyBuffer;
			memcpy(buf->data_, &x32, sizeof(x32));
			break;
		case Type::TT_INT64:
			if (sizeof(xiv) == sizeof(x64)) { // 64-bit machine, copy directly
				x64 = SvIV(arg);
				buf = new(sizeof(x64)) EasyBuffer;
				memcpy(buf->data_, &x64, sizeof(x64));
			} else { // 32-bit machine, int64 represented in Perl as double
				x64 = SvNV(arg);
				buf = new(sizeof(x64)) EasyBuffer;
				memcpy(buf->data_, &x64, sizeof(x64));
			}
			break;
		case Type::TT_FLOAT64:
			xfv = SvNV(arg);
			buf = new(sizeof(xfv)) EasyBuffer;
			memcpy(buf->data_, &xfv, sizeof(xfv));
			break;
		default:
			setErrMsg(strprintf("Biceps field '%s' data conversion: invalid field type???", fname));
			return NULL;
			break;
		}
	}
	return buf;
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
WrapRowType *
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



