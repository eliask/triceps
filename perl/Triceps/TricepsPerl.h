//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// Helper functions for Perl wrapper.

#include <string.h>
#include <wrap/Wrap.h>
#include <common/Conf.h>
#include <common/Strprintf.h>
#include <common/Exception.h>
#include <mem/EasyBuffer.h>

// ###################################################################################

#ifndef __TricepsPerl_TricepsPerl_h__
#define __TricepsPerl_TricepsPerl_h__

using namespace TRICEPS_NS;

namespace TRICEPS_NS
{
namespace TricepsPerl 
{
// To call Perl_croak() with arbitrary messages, the message must be in the
// memory that will be cleaned by Perl, since croak() does a longjmp and bypasses
// the destructors. It must also be per-thread. Since the Perl variables 
// are per-thread, the value get stored in a Perl variable, and then
// a pointer to that value gets passed to croak().
void setCroakMsg(const std::string &msg);
// Get back the croak message string. It it located in the variable Triceps::_CROAK_MSG.
const char *getCroakMsg();

// Check the contents of the croak message, and if it's set then croak.
void croakIfSet();

// Clear the perl $! variable and the Triceps::_CROAK_MSG.
void clearErrMsg();

// Set a message in Perl $! variable, and also set the croak message.
// @param msg - error message
void setErrMsg(const std::string &msg);

// Copy a Perl scalar (numeric) SV value into a memory buffer.
// @param ti - field type selection
// @param val - SV to copy from
// @param bytes - memory buffer to copy to, must be large enough
// @return - true if set OK, false if value was non-numeric
bool svToBytes(Type::TypeId ti, SV *val, char *bytes);

// Convert a Perl value (scalar or list) to a buffer
// with raw bytes suitable for setting into a record.
// Does NOT check for undef, the caller must do that before.
// Also silently allows to set the arrays for the scalar fields
// and scalars into arrays.
// 
// @param ti - field type selection
// @param arg - value to post to, must be already checked for SvOK
// @param fname - field name, for error messages
// @return - new buffer (with size_ set), or NULL (then with error set)
EasyBuffer * valToBuf(Type::TypeId ti, SV *arg, const char *fname);

// Convert a byte buffer from a row to a Perl value.
// @param ti - id of the simple type
// @param arsz - array size, affects the resulting value:
//        Type::AR_SCALAR - returns a scalar
//        anything else - returns an array reference
//        (except that TT_STRING and TT_UINT8 are always returned as Perl scalar strings)
// @param notNull - if false, returns an undef (suiitable for putting in an array)
// @param data - the raw data buffer
// @param dlen - data buffer length
// @param fname - field name, for error messages
// @return - a new SV
SV *bytesToVal(Type::TypeId ti, int arsz, bool notNull, const char *data, intptr_t dlen, const char *fname);

// Parse an option value of reference to array into a NameSet
// On error calls setErrMsg and returns NULL.
// @param funcName - calling function name, for error messages
// @param optname - option name of the originating value, for error messages
// @param ref - option value (will be checked for being a reference to array)
// @return - the parsed NameSet or NULL on error
Onceref<NameSet> parseNameSet(const char *funcName, const char *optname, SV *optval);

// Parse an enqueuing mode as an integer or string constant to an enum.
// On error calls setErrMsg and returns false.
// @param funcName - calling function name, for error messages
// @param enqMode - SV containing the value to parse
// @param em - place to return the parsed value
// @return - true on success or false on error
bool parseEnqMode(const char *funcName, SV *enqMode, Gadget::EnqMode &em);

// Parse an opcode as an integer or string constant to an enum.
// On error calls setErrMsg and returns false.
// @param funcName - calling function name, for error messages
// @param opcode - SV containing the value to parse
// @param op - place to return the parsed value
// @return - true on success or false on error
bool parseOpcode(const char *funcName, SV *opcode, Rowop::Opcode &op);

// Parse an IndexId as an integer or string constant to an enum.
// On error calls setErrMsg and returns false.
// @param funcName - calling function name, for error messages
// @param idarg - SV containing the value to parse
// @param id - place to return the parsed value
// @return - true on success or false on error
bool parseIndexId(const char *funcName, SV *idarg, IndexType::IndexId &id);

// Enqueue one argument in a unit. The argument may be either a Rowop or a Tray,
// detected automatically. Checks for errors and populates the error messages.
// @param funcName - calling function name, for error messages
// @param u - unit where to enqueue
// @param mark - loop mark, if not NULL then used to fork at this frame and em 
//     is ignored
// @param em - enqueuing mode (used if mark is not NULL)
// @param arg - argument (should be Rowop or Tray reference)
// @param i - argument number, for error messages
// @return - true on success, false on error
bool enqueueSv(char *funcName, Unit *u, FrameMark *mark, Gadget::EnqMode em, SV *arg, int i);

// The Unit::Tracer subclasses hierarchy is partially exposed to Perl. So an Unit::Tracer
// object can not be returned to Perl by a simple wrapping and blessing to a fixed class.
// Instead its recognised subclasses must be blessed to the correct Perl classes.
// This function returns the correct perl class for blessing.
// @param tr - tracer object (must not be NULL!!!)
// @return - perl class name, in a static string (which must be never modified!)
char *translateUnitTracerSubclass(const Unit::Tracer *tr);

// A common macro to print the contents of assorted objects.
// See RowType.xs for an example of usage
#define GEN_PRINT_METHOD(subtype)  \
		static char funcName[] =  "Triceps::" #subtype "::print"; \
		clearErrMsg(); \
		subtype *rt = self->get(); \
		\
		if (items > 3) { \
			setErrMsg( strprintf("Usage: %s(self [, indent  [, subindent ] ])", funcName)); \
			XSRETURN_UNDEF; \
		} \
		\
		string indent, subindent; \
		const string *indarg = &indent; \
		\
		if (items > 1) { /* parse indent */ \
			if (SvOK(ST(1))) { \
				const char *p; \
				STRLEN len; \
				p = SvPV(ST(1), len); \
				indent.assign(p, len); \
			} else { \
				indarg = &NOINDENT; \
			} \
		} \
		if (items > 2) { /* parse subindent */ \
			const char *p; \
			STRLEN len; \
			p = SvPV(ST(2), len); \
			subindent.assign(p, len); \
		} else { \
			subindent.assign("  "); \
		} \
		\
		string res; \
		rt->printTo(res, *indarg, subindent); \
		XPUSHs(sv_2mortal(newSVpvn(res.c_str(), res.size())));

// A common macro to catch the Triceps::Exception and convert it to a croak.
// Use:
//
// try {
//     ... some code ...
// } TRICEPS_CATCH_CROAK;
//
// Make sure to define all your C++ variables with destructors inside the try block!!!
#define TRICEPS_CATCH_CROAK \
	catch (Exception e) { \
		setCroakMsg(e.getErrors()->print()); \
	} \
	croakIfSet()

}; // Triceps::TricepsPerl
}; // Triceps

using namespace TRICEPS_NS::TricepsPerl;

#endif // __TricepsPerl_TricepsPerl_h__
