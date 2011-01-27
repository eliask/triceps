#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "const-c.inc"

#include <wrap/Wrap.h>

using namespace Biceps;

MODULE = Biceps		PACKAGE = Biceps

INCLUDE: const-xs.inc

MODULE = Biceps		PACKAGE = Biceps::RowType

WrapRowType *
Biceps::RowType::new(...)
	CODE:
		RowType::FieldVec fld;

		if (items < 3 || items % 2 != 1) {
			warn("Usage: %s(%s), names and types must go in pairs", "Biceps::RowType::new", "CLASS, fieldName, fieldType, ...");
			XSRETURN_UNDEF;
		}
		for (int i = 1; i < items; i += 2) {
			const char *fname = (const char *)SvPV_nolen(ST(i));
			const char *ftype = (const char *)SvPV_nolen(ST(i+1));
			RowType::Field add(fname, Type::findSimpleType(ftype));
			if (add.type_.isNull()) {
				warn("%s: field '%s' has an unknown type '%s'", "Biceps::RowType::new", fname, ftype);
				XSRETURN_UNDEF;
			}
			fld.push_back(add);
		}
		Onceref<RowType> rt = new CompactRowType(fld);
		Erref err = rt->getErrors();
		if (!err.isNull() && !err->isEmpty()) {
			string msg = err->print();
			warn("%s: %s", "Biceps::RowType::new", msg.c_str());
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
