//
// (C) Copyright 2011-2012 Sergey A. Babkin.
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
XS(boot_Triceps__RowHandle); 
XS(boot_Triceps__RowType); 
XS(boot_Triceps__IndexType); 
XS(boot_Triceps__TableType); 
XS(boot_Triceps__Tray); 
XS(boot_Triceps__Unit); 
XS(boot_Triceps__UnitTracer); 
XS(boot_Triceps__Table); 
XS(boot_Triceps__AggregatorType); 
XS(boot_Triceps__AggregatorContext); 
XS(boot_Triceps__FrameMark); 
XS(boot_Triceps__FnReturn); 
XS(boot_Triceps__FnBinding); 
XS(boot_Triceps__AutoFnBind); 
#ifdef __cplusplus
};
#endif

MODULE = Triceps		PACKAGE = Triceps

BOOT:
	// the exceptions will be caught and backtraced in Perl
	TRICEPS_NS::Exception::abort_ = false;
	TRICEPS_NS::Exception::enableBacktrace_ = false;
	//
	// boot sub-packages that are compiled separately
	//
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
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__RowHandle(aTHX_ cv); 
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
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__AggregatorType(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__AggregatorContext(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__FrameMark(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__FnReturn(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__FnBinding(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__AutoFnBind(aTHX_ cv); 
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

############ conversions of strings to enum constants #############################
# (this duplicates the Triceps:: constant definitions but comes useful once in a while
# the error values are converted to undefs

int
stringOpcode(char *val)
	CODE:
		clearErrMsg();
		int res = Rowop::stringOpcode(val);
		if (res == Rowop::OP_BAD)
			XSRETURN_UNDEF;
		RETVAL = res;
	OUTPUT:
		RETVAL

int
stringOcf(char *val)
	CODE:
		clearErrMsg();
		int res = Rowop::stringOcf(val);
		if (res == -1)
			XSRETURN_UNDEF;
		RETVAL = res;
	OUTPUT:
		RETVAL

int
stringEm(char *val)
	CODE:
		clearErrMsg();
		int res = Gadget::stringEm(val);
		if (res == -1)
			XSRETURN_UNDEF;
		RETVAL = res;
	OUTPUT:
		RETVAL

int
stringTracerWhen(char *val)
	CODE:
		clearErrMsg();
		int res = Unit::stringTracerWhen(val);
		if (res == -1)
			XSRETURN_UNDEF;
		RETVAL = res;
	OUTPUT:
		RETVAL

int
humanStringTracerWhen(char *val)
	CODE:
		clearErrMsg();
		int res = Unit::humanStringTracerWhen(val);
		if (res == -1)
			XSRETURN_UNDEF;
		RETVAL = res;
	OUTPUT:
		RETVAL

int
stringIndexId(char *val)
	CODE:
		clearErrMsg();
		int res = IndexType::stringIndexId(val);
		if (res == -1)
			XSRETURN_UNDEF;
		RETVAL = res;
	OUTPUT:
		RETVAL

int
stringAggOp(char *val)
	CODE:
		clearErrMsg();
		int res = Aggregator::stringAggOp(val);
		if (res == -1)
			XSRETURN_UNDEF;
		RETVAL = res;
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

char *
tracerWhenString(int val)
	CODE:
		clearErrMsg();
		const char *res = Unit::tracerWhenString(val, NULL);
		if (res == NULL)
			XSRETURN_UNDEF;
		RETVAL = (char *)res;
	OUTPUT:
		RETVAL

char *
tracerWhenHumanString(int val)
	CODE:
		clearErrMsg();
		const char *res = Unit::tracerWhenHumanString(val, NULL);
		if (res == NULL)
			XSRETURN_UNDEF;
		RETVAL = (char *)res;
	OUTPUT:
		RETVAL

char *
indexIdString(int val)
	CODE:
		clearErrMsg();
		const char *res = IndexType::indexIdString(val, NULL);
		if (res == NULL)
			XSRETURN_UNDEF;
		RETVAL = (char *)res;
	OUTPUT:
		RETVAL

char *
aggOpString(int val)
	CODE:
		clearErrMsg();
		const char *res = Aggregator::aggOpString(val, NULL);
		if (res == NULL)
			XSRETURN_UNDEF;
		RETVAL = (char *)res;
	OUTPUT:
		RETVAL

# Works only on the constant, not on the string value.
int
tracerWhenIsBefore(int val)
	CODE:
		clearErrMsg();
		RETVAL = Unit::tracerWhenIsBefore(val);
	OUTPUT:
		RETVAL

# Works only on the constant, not on the string value.
int
tracerWhenIsAfter(int val)
	CODE:
		clearErrMsg();
		RETVAL = Unit::tracerWhenIsAfter(val);
	OUTPUT:
		RETVAL
