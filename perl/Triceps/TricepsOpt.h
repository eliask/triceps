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

// Get the pointer to a Triceps class wrap object from a Perl SV value.
// Throws a Triceps::Exception if the value is incorrect.
//
// It is structured as two parts:
// * the macro that manipulates the class names, so that multiple versions
//   of them don't have to be specified explicitly
// * the template that does the actual work
//
// An example of use:
//   Unit *u = TRICEPS_GET_WRAP(Unit, ST(i), "%s: option '%s'", funcName, optName)->get();
//
// @param TClass - type of object, whose wrapper is to be extracted from SV
// @param svptr - the Perl SV* from which the value will be extracted
// @param fmt, ...  - the custom initial part for the error messages in the exception
// @return - the Triceps wrapper class for which the value is being extracted;
//           guaranteed to be not NULL, so get() can be called on it right away
//           (the reason for not returning the value from the wrapper is that
//           for some wrappers there is also a type to get from it)
#define TRICEPS_GET_WRAP(TClass, svptr, fmt, ...) GetSvWrap<TRICEPS_NS::Wrap##TClass>(svptr, #TClass, fmt, __VA_ARGS__)

// @param WrapClass - the perl wrapper class around the Triceps class
// @param var - variable to return the pointer to the object
// @param svptr - Perl value to get the object from
// @param className - name of the TClass as a string, for error messages
// @param fmt, ... - the prefix for the error message
// @return - the Triceps wrapper class for which the value is being extracted
template<class WrapClass>
WrapClass *GetSvWrap(SV *svptr, const char *className, const char *fmt, ...)
	__attribute__((format(printf, 3, 4)));

template<class WrapClass>
WrapClass *GetSvWrap(SV *svptr, const char *className, const char *fmt, ...)
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
	return wvar;
}

// Extract a string from a Perl SV value.
// Throws a Triceps::Exception if the value is not SvPOK().
//
// @param res - variable to return the string into
// @param svptr - the Perl SV* from which the value will be extracted
// @param fmt, ... - the prefix for the error message
void GetSvString(string &res, SV *svptr, const char *fmt, ...);

// Extract an array reference from a Perl SV value.
// Throws a Triceps::Exception if the value is not an array reference.
//
// @param svptr - the Perl SV* from which the value will be extracted
// @param fmt, ... - the prefix for the error message
// @return - the array pointer
AV *GetSvArray(SV *svptr, const char *fmt, ...);

}; // Triceps::TricepsPerl
}; // Triceps

using namespace TRICEPS_NS::TricepsPerl;

#endif // __TricepsPerl_TricepsOpt_h__
