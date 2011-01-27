#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "const-c.inc"

#include <wrap/Wrap.h>
#include <common/Strprintf.h>

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

MODULE = Biceps		PACKAGE = Biceps

INCLUDE: const-xs.inc

MODULE = Biceps		PACKAGE = Biceps::RowType

WrapRowType *
Biceps::RowType::new(...)
	CODE:
		RowType::FieldVec fld;

		if (items < 3 || items % 2 != 1) {
			setErrMsg("Usage: Biceps::RowType::new(CLASS, fieldName, fieldType, ...), names and types must go in pairs");
			XSRETURN_UNDEF;
		}
		for (int i = 1; i < items; i += 2) {
			const char *fname = (const char *)SvPV_nolen(ST(i));
			const char *ftype = (const char *)SvPV_nolen(ST(i+1));
			RowType::Field add(fname, Type::findSimpleType(ftype));
			if (add.type_.isNull()) {
				setErrMsg(strprintf("%s: field '%s' has an unknown type '%s'", "Biceps::RowType::new", fname, ftype));
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
