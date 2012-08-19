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
		throw Exception(strprintf("%s value must be a blessed SV reference to Triceps::%s", 
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

// Get the pointer to a Triceps class wrap object from a Perl SV value
// that may be one of 2 types. One of the result pointers will be
// populated, the other will be NULL.
// Throws a Triceps::Exception if the value is neither.
//
// It is structured as two parts:
// * the macro that manipulates the class names, so that multiple versions
//   of them don't have to be specified explicitly
// * the template that does the actual work
//
// An example of use (different from TRICEPS_GET_WRAP):
//   TRICEPS_GET_WRAP2(Label, wlb, RowType, wrt, ST(i), "%s: option '%s'", funcName, optName);
//
// @param TClass1 - type 1 of object, whose wrapper is to be extracted from SV
// @param wrap1 - reference to return the value of type 1
// @param TClass2 - type 2 of object, whose wrapper is to be extracted from SV
// @param wrap2 - reference to return the value of type 2
// @param svptr - the Perl SV* from which the value will be extracted
// @param fmt, ...  - the custom initial part for the error messages in the exception
// @return - the Triceps wrapper class for which the value is being extracted;
//           guaranteed to be not NULL, so get() can be called on it right away
//           (the reason for not returning the value from the wrapper is that
//           for some wrappers there is also a type to get from it)
#define TRICEPS_GET_WRAP2(TClass1, wrap1, TClass2, wrap2, svptr, fmt, ...) GetSvWrap2<TRICEPS_NS::Wrap##TClass1, TRICEPS_NS::Wrap##TClass2>(wrap1, wrap2, svptr, #TClass1, #TClass2, fmt, __VA_ARGS__)

// @param WrapClass1 - wrap type 1 of object, that is to be extracted from SV
// @param WrapClass2 - wrap type 2 of object, that is to be extracted from SV
// @param wrap1 - reference to return the value of type 1
// @param wrap2 - reference to return the value of type 2
// @param svptr - Perl value to get the object from
// @param className1 - name of the TClass1 as a string, for error messages
// @param className2 - name of the TClass2 as a string, for error messages
// @param fmt, ... - the prefix for the error message
// @return - the Triceps wrapper class for which the value is being extracted
template<class WrapClass1, class WrapClass2>
void GetSvWrap2(WrapClass1 *&wrap1, WrapClass2 *&wrap2, SV *svptr, const char *className1, const char *className2, const char *fmt, ...)
	__attribute__((format(printf, 6, 7)));

template<class WrapClass1, class WrapClass2>
void GetSvWrap2(WrapClass1 *&wrap1, WrapClass2 *&wrap2, SV *svptr, const char *className1, const char *className2, const char *fmt, ...)
{
	if (!sv_isobject(svptr) || SvTYPE(SvRV(svptr)) != SVt_PVMG) {
		va_list ap;
		va_start(ap, fmt);
		string s = vstrprintf(fmt, ap);
		va_end(ap);
		throw Exception(strprintf("%s value must be a blessed SV reference to Triceps::%s or Triceps::%s", 
			s.c_str(), className1, className2), false);
	}

	IV ref = SvIV((SV*)SvRV( svptr ));
	wrap1 = (WrapClass1 *)ref;
	wrap2 = (WrapClass2 *)ref;
	if (ref) {
		if (!wrap1->badMagic()) {
			wrap2 = NULL;
		} else if (!wrap2->badMagic()) {
			wrap1 = NULL;
		} else {
			ref = 0;
		}
	}
	if (ref == 0) {
		va_list ap;
		va_start(ap, fmt);
		string s = vstrprintf(fmt, ap);
		va_end(ap);
		throw Exception(strprintf("%s value has an incorrect magic for either Triceps::%s or Triceps::%s", 
			s.c_str(), className1, className2), false);
	}
}

// Extract a string from a Perl SV value.
// Throws a Triceps::Exception if the value is not SvPOK().
//
// @param res - variable to return the string into
// @param svptr - the Perl SV* from which the value will be extracted
// @param fmt, ... - the prefix for the error message
void GetSvString(string &res, SV *svptr, const char *fmt, ...)
	__attribute__((format(printf, 3, 4)));

// Extract an array reference from a Perl SV value.
// Throws a Triceps::Exception if the value is not an array reference.
//
// @param svptr - the Perl SV* from which the value will be extracted
// @param fmt, ... - the prefix for the error message
// @return - the array pointer
AV *GetSvArray(SV *svptr, const char *fmt, ...)
	__attribute__((format(printf, 2, 3)));

// The typical argument for binding or function returns: either a
// ready label or a Perl code reference (for which a label will be
// created automatically).
// Throws a Triceps::Exception if the value is not correct.
//
// @param svptr - the Perl SV* from which the value will be extracted
// @param fmt, ... - the prefix for the error message
// @return - the label pointer (not WrapLabel!); since the code reference
//     SV doesn't need any transformations to be used in a label, the case
//     when NULL is returned but no exception thrown means that the svptr
//     is a code reference.
Label *GetSvLabelOrCode(SV *svptr, const char *fmt, ...)
	__attribute__((format(printf, 2, 3)));

}; // Triceps::TricepsPerl
}; // Triceps

using namespace TRICEPS_NS::TricepsPerl;

#endif // __TricepsPerl_TricepsOpt_h__
