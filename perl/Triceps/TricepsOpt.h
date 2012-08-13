//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// Option parsing to be used from the XS code.

// ###################################################################################

#ifndef __TricepsPerl_TricepsOpt_h__
#define __TricepsPerl_TricepsOpt_h__

#include "TricepsPerl.h"
#include <common/Strprintf.h>

using namespace TRICEPS_NS;

namespace TRICEPS_NS
{
namespace TricepsPerl 
{

// Get the pointer to a Triceps class object from a Perl SV value.
// Throws a Triceps::Exception if the value is incorrect.
//
// It is structured as two parts:
// * the macro that manipulates the class names, so that multiple versions
//   of them don't have to be specified explicitly
// * the template that does the actual work
//
// An example of use:
//   Unit *u = NULL;
//   TRICEPS_GET_OBJECT(Unit, u, ST(i), "%s: option '%s'", funcName, optName)
//
// @param TClass - Triceps class, to which value we're getting a pointer
// @param var - an already defined valiable where the value will be returned
// @param svptr - the Perl SV* from which the value will be extracted
// @param fmt, ...  - the custom initial part for the error messages in the exception
#define TRICEPS_GET_OBJECT(TClass, var, svptr, fmt, ...) GetObject<TRICEPS_NS::TClass, TRICEPS_NS::Wrap##TClass>(var, svptr, #TClass, fmt, __VA_ARGS__)

// @param TClass - the Triceps class for which the value is being extracted
// @param WrapClass - the perl wrapper class around the Triceps class
// @param var - variable to return the pointer to the object
// @param val - Perl value to get the object from
// @param className - name of the TClass as a string, for error messages
// @fmt, ... - the prefix for the error message
template<class TClass, class WrapClass>
void GetObject(TClass *&var, SV *svptr, const char *className, const char *fmt, ...)
	__attribute__((format(printf, 4, 5)));

template<class TClass, class WrapClass>
void GetObject(TClass *&var, SV *svptr, const char *className, const char *fmt, ...)
{
	if (!sv_isobject(svptr) || SvTYPE(SvRV(svptr)) != SVt_PVMG) {
		va_list ap;
		va_start(ap, fmt);
		string s = vstrprintf(fmt, ap);
		va_end(ap);
		throw Exception(strprintf("%s value is not a blessed SV reference to Triceps::%s", 
			s.c_str(), className), false);
	}
	WrapClass *wvar = (WrapClass *)SvIV((SV*)SvRV( svptr ));
	if (wvar == NULL || wvar->badMagic()) {
		va_list ap;
		va_start(ap, fmt);
		string s = vstrprintf(fmt, ap);
		va_end(ap);
		throw Exception(strprintf("%s value has an incorrect magic for Triceps::%s", s.c_str(), className), false);
	}
	var = wvar->get();
}

}; // Triceps::TricepsPerl
}; // Triceps

using namespace TRICEPS_NS::TricepsPerl;

#endif // __TricepsPerl_TricepsOpt_h__
