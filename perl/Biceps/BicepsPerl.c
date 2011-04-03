//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// Helper functions for Perl wrapper.
// This is really a .cpp file but Makefile.PL understands only .c

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "const-c.inc"

#include "BicepsPerl.h"

// ###################################################################################

using namespace Biceps;

namespace Biceps
{
namespace BicepsPerl 
{

void clearErrMsg()
{
	SV *errsv = get_sv("!", 0);
	if (errsv) {
		sv_setpvn(errsv, "", 0);
	}
}

void setErrMsg(const std::string &msg)
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

bool svToBytes(Type::TypeId ti, SV *val, char *bytes)
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

EasyBuffer * valToBuf(Type::TypeId ti, SV *arg, const char *fname)
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

Onceref<NameSet> parseNameSet(const char *funcName, const char *optname, SV *optval)
{
	if (!SvROK(optval) || SvTYPE(SvRV(optval)) != SVt_PVAV) {
		setErrMsg(strprintf("%s: option '%s' value must be an array reference", funcName, optname));
		return NULL;
	}
	Onceref<NameSet> key = new NameSet;
	AV *ka = (AV *)SvRV(optval);
	int klen = av_len(ka);
	for (int j = 0; j <= klen; j++) {
		SV *fldsv = *av_fetch(ka, j, 1);
		STRLEN len;
		char *fld = SvPV(fldsv, len);
		key->add(string(fld, len));
	}
	return key;
}

}; // Biceps::BicepsPerl
}; // Biceps

using namespace Biceps::BicepsPerl;

