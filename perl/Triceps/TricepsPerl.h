//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// Helper functions for Perl wrapper.

#include <string.h>
#include <wrap/Wrap.h>
#include <common/Strprintf.h>
#include <mem/EasyBuffer.h>

// ###################################################################################

using namespace Triceps;

namespace Triceps
{
namespace TricepsPerl 
{

// Clear the perl $! variable
void clearErrMsg();

// Set a message in Perl $! variable
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

}; // Triceps::TricepsPerl
}; // Triceps

using namespace Triceps::TricepsPerl;

