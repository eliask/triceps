//
// (C) Copyright 2011 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// Helper functions for Perl wrapper.

#include <typeinfo>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "PerlCallback.h"

// ###################################################################################

using namespace Triceps;

namespace Triceps
{
namespace TricepsPerl 
{

void clearErrMsg()
{
	SV *errsv = get_sv("!", 0);
	if (errsv) {
		sv_setpvn(errsv, "", 0);
	}
}

// XXX Add mode when all the error messages will be fatal?
// This will work only with exit(1), not croak() because croak() would mess up C++ stack.

// XXX Should also set the numeric value to EINVAL?

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
		warn("Triceps: can not set $! with error: %s", msg.c_str());
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
		croak("Triceps svToBytes called with unsupported type %d\n", ti);
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
	// (an interesting side effect is that if a number is set to an uint8 field, it will
	// be converted to string first and then set; to avoid this, use chr())
	switch(ti) {
	case Type::TT_UINT8:
	case Type::TT_STRING:
		if (SvROK(arg)) {
			setErrMsg(strprintf("Triceps field '%s' data conversion: array reference may not be used for string and uint8", fname));
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
		setErrMsg(strprintf("Triceps field '%s' data conversion: invalid field type???", fname));
		return NULL;
		break;
	}

	// by now it's known to be a numeric type, with value size in slen

	if (SvROK(arg)) {
		AV *lst = (AV *)SvRV(arg);
		if (SvTYPE(lst) != SVt_PVAV) {
			setErrMsg(strprintf("Triceps field '%s' data conversion: reference not to an array", fname));
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
				setErrMsg(strprintf("Triceps field '%s' element %d data conversion: non-numeric value", fname, i));
				return NULL;
			}
		}
	} else {
		buf = new(slen) EasyBuffer;
		buf->size_ = slen;
		if (!svToBytes(ti, arg,  buf->data_)) {
			delete buf;
			setErrMsg(strprintf("Triceps field '%s' data conversion: non-numeric value", fname));
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
			warn("Triceps field '%s' data conversion: invalid field type???", fname);
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
			warn("Triceps field '%s' data conversion: invalid field type???", fname);
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

bool parseEnqMode(const char *funcName, SV *enqMode, Gadget::EnqMode &em)
{
	int intem;
	// accept enqueueing mode as either number of name
	if (SvIOK(enqMode)) {
		intem = SvIV(enqMode);
		if (Gadget::emString(intem, NULL) == NULL) {
			setErrMsg(strprintf("%s: unknown enqueuing mode integer %d", funcName, intem));
			return false;
		}
		// em = (Gadget::EnqMode)intem;
	} else {
		const char *emname = SvPV_nolen(enqMode);
		intem = Gadget::stringEm(emname);
		if (intem == -1) {
			setErrMsg(strprintf("%s: unknown enqueuing mode string '%s', if integer was meant, it has to be cast", funcName, emname));
			return false;
		}
	}
	em = (Gadget::EnqMode)intem;
	return true;
}

bool parseOpcode(const char *funcName, SV *opcode, Rowop::Opcode &op)
{
	int intop;
	// accept opcode as either number of name
	if (SvIOK(opcode)) {
		intop = SvIV(opcode);
	} else {
		const char *opname = SvPV_nolen(opcode);
		intop = Rowop::stringOpcode(opname);
		if (intop == Rowop::OP_BAD) {
			setErrMsg(strprintf("%s: unknown opcode string '%s', if integer was meant, it has to be cast", funcName, opname));
			return false;
		}
	}
	op = (Rowop::Opcode)intop;
	return true;
}

bool parseIndexId(const char *funcName, SV *idarg, IndexType::IndexId &id)
{
	int intid;
	// accept idarg as either number of name
	if (SvIOK(idarg)) {
		intid = SvIV(idarg);
	} else {
		const char *idname = SvPV_nolen(idarg);
		intid = IndexType::stringIndexId(idname);
		if (intid < 0) {
			setErrMsg(strprintf("%s: unknown IndexId string '%s', if integer was meant, it has to be cast", funcName, idname));
			return false;
		}
	}
	id = (IndexType::IndexId)intid;
	return true;
}

bool enqueueSv(char *funcName, Unit *u, FrameMark *mark, Gadget::EnqMode em, SV *arg, int i)
{
	if( sv_isobject(arg) && (SvTYPE(SvRV(arg)) == SVt_PVMG) ) {
		WrapRowop *wrop = (WrapRowop *)SvIV((SV*)SvRV( arg ));
		WrapTray *wtray = (WrapTray *)wrop;
		if (wrop != 0 && !wrop->badMagic()) {
			Rowop *rop = wrop->get();
			if (rop->getLabel()->getUnitPtr() != u) {
				setErrMsg( strprintf("%s: argument %d is a Rowop for label %s from a wrong unit %s", funcName, i,
					rop->getLabel()->getName().c_str(), rop->getLabel()->getUnitName().c_str()) );
				return false;
			}
			if (mark)
				u->loopAt(mark, rop);
			else
				u->enqueue(em, rop);
		} else if (wtray != 0 && !wtray->badMagic()) {
			if (wtray->getParent() != u) {
				setErrMsg( strprintf("%s: argument %d is a Tray from a wrong unit %s", funcName, i,
					wtray->getParent()->getName().c_str()) );
				return false;
			}
			if (mark)
				u->loopTrayAt(mark, wtray->get());
			else
				u->enqueueTray(em, wtray->get());
		} else {
			setErrMsg( strprintf("%s: argument %d has an incorrect magic for either Rowop or Tray", funcName, i) );
			return false;
		}
	} else{
		setErrMsg( strprintf("%s: argument %d is not a blessed SV reference to Rowop", funcName, i) );
		return false;
	}
	return true;
}

char *translateUnitTracerSubclass(const Unit::Tracer *tr)
{
	static char base[] = "Triceps::UnitTracer";
	static char strn[] = "Triceps::UnitTracerStringName";
	static char pl[] = "Triceps::UnitTracerPerl";
	try {
		const type_info &trinfo = typeid(*tr);
		if (trinfo == typeid(Unit::StringNameTracer))
			return strn;
		else if (trinfo == typeid(UnitTracerPerl))
			return pl;
		else
			return base;
	} catch(...) {
		abort();
	}
}

}; // Triceps::TricepsPerl
}; // Triceps


