//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The main file including all the parts of Biceps XS interface.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "BicepsPerl.h"

#include "const-c.inc"

#ifdef __cplusplus
extern "C" {
#endif
XS(boot_Biceps__Label); 
XS(boot_Biceps__Row); 
XS(boot_Biceps__RowType); 
XS(boot_Biceps__IndexType); 
XS(boot_Biceps__TableType); 
XS(boot_Biceps__Unit); 
XS(boot_Biceps__Table); 
#ifdef __cplusplus
};
#endif

MODULE = Biceps		PACKAGE = Biceps

BOOT:
	# boot sub-packages that are compiled separately
	// fprintf(stderr, "DEBUG Biceps items=%d sp=%p mark=%p\n", items, sp, mark);
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Biceps__Label(aTHX_ cv); 
	SPAGAIN; POPi;
	//
	// fprintf(stderr, "DEBUG Biceps items=%d sp=%p mark=%p\n", items, sp, mark);
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Biceps__Row(aTHX_ cv); 
	SPAGAIN; POPi;
	//
	// fprintf(stderr, "DEBUG Biceps items=%d sp=%p mark=%p\n", items, sp, mark);
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Biceps__RowType(aTHX_ cv); 
	SPAGAIN; POPi;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Biceps__IndexType(aTHX_ cv); 
	SPAGAIN; POPi;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Biceps__TableType(aTHX_ cv); 
	SPAGAIN; POPi;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Biceps__Unit(aTHX_ cv); 
	SPAGAIN; POPi;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Biceps__Table(aTHX_ cv); 
	SPAGAIN; POPi;
	//
	// fprintf(stderr, "DEBUG Biceps items=%d sp=%p mark=%p\n", items, sp, mark);


INCLUDE: const-xs.inc

