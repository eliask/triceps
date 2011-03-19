//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Helper functions working with strings

#ifndef __Biceps_StringUtil_h__
#define __Biceps_StringUtil_h__

#include <common/Common.h>
#include <stdio.h>

namespace BICEPS_NS {

// A special reference to a string, passed around to indicate that the
// printing must be done without line breaks.
// Doesn't work on all printing functions, just where supported.
extern const string &NOINDENT;

// Print a byte buffer in hex
// @param dest - file to print to
// @param bytes - bytes to dump
// @param n - number of bytes
// @param indent - indent string
void hexdump(FILE *dest, const void *bytes, size_t n, const char *indent = "");

// same, append to a string
void hexdump(string &dest, const void *bytes, size_t n, const char *indent = "");

}; // BICEPS_NS

#endif // __Biceps_StringUtil_h__
