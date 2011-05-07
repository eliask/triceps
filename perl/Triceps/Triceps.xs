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
XS(boot_Triceps__RowType); 
XS(boot_Triceps__IndexType); 
XS(boot_Triceps__TableType); 
XS(boot_Triceps__Unit); 
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
	boot_Triceps__Unit(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	PUSHMARK(SP); if (items >= 2) { XPUSHs(ST(0)); XPUSHs(ST(1)); } PUTBACK; 
	boot_Triceps__Table(aTHX_ cv); 
	SPAGAIN; POPs;
	//
	// fprintf(stderr, "DEBUG Triceps items=%d sp=%p mark=%p\n", items, sp, mark);


INCLUDE: const-xs.inc

