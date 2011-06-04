//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The main file including all the parts of Triceps XS interface.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

#include "const-c.inc"

#ifdef __cplusplus
extern "C" {
#endif
XS(boot_Triceps__Label); 
XS(boot_Triceps__Row); 
XS(boot_Triceps__Rowop); 
XS(boot_Triceps__RowType); 
XS(boot_Triceps__IndexType); 
XS(boot_Triceps__TableType); 
XS(boot_Triceps__Tray); 
XS(boot_Triceps__Unit); 
XS(boot_Triceps__UnitTracer); 
XS(boot_Triceps__Table); 
#ifdef __cplusplus
};
#endif

MODULE = Triceps		PACKAGE = Triceps

BOOT:
	# boot sub-packages that are compiled separately
	// fprintf(stderr, "DEBUG Triceps items=%d sp=%p mark=%p\n", items, sp, mark);
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__Label(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	// fprintf(stderr, "DEBUG Triceps items=%d sp=%p mark=%p\n", items, sp, mark);
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__Row(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__Rowop(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	// fprintf(stderr, "DEBUG Triceps items=%d sp=%p mark=%p\n", items, sp, mark);
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__RowType(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__IndexType(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__TableType(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__Tray(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__Unit(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__UnitTracer(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__Table(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	// fprintf(stderr, "DEBUG Triceps items=%d sp=%p mark=%p\n", items, sp, mark);


INCLUDE: const-xs.inc

############## static functions from Rowop, in perl they move to Triceps:: ###########

int
isInsert(int op)
	CODE:
		clearErrMsg();
		RETVAL = Rowop::isInsert(op);
	OUTPUT:
		RETVAL

int
isDelete(int op)
	CODE:
		clearErrMsg();
		RETVAL = Rowop::isDelete(op);
	OUTPUT:
		RETVAL

int
isNop(int op)
	CODE:
		clearErrMsg();
		RETVAL = Rowop::isNop(op);
	OUTPUT:
		RETVAL

############ conversions of constants back to string #############################

char *
opcodeString(int val)
	CODE:
		clearErrMsg();
		const char *res = Rowop::opcodeString(val); // never returns NULL
		RETVAL = (char *)res;
	OUTPUT:
		RETVAL

char *
ocfString(int val)
	CODE:
		clearErrMsg();
		const char *res = Rowop::ocfString(val, NULL);
		if (res == NULL)
			XSRETURN_UNDEF;
		RETVAL = (char *)res;
	OUTPUT:
		RETVAL

char *
emString(int val)
	CODE:
		clearErrMsg();
		const char *res = Gadget::emString(val, NULL);
		if (res == NULL)
			XSRETURN_UNDEF;
		RETVAL = (char *)res;
	OUTPUT:
		RETVAL

char *tracerWhenString(int val)
	CODE:
		clearErrMsg();
		const char *res = Unit::tracerWhenString(val, NULL);
		if (res == NULL)
			XSRETURN_UNDEF;
		RETVAL = (char *)res;
	OUTPUT:
		RETVAL

char *tracerWhenHumanString(int val)
	CODE:
		clearErrMsg();
		const char *res = Unit::tracerWhenHumanString(val, NULL);
		if (res == NULL)
			XSRETURN_UNDEF;
		RETVAL = (char *)res;
	OUTPUT:
		RETVAL

# XXX also add functions to translate from string to enum
