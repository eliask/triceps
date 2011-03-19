//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Helper functions working with strings

#include <common/StringUtil.h>
#include <common/Strprintf.h>
#include <ctype.h>

namespace BICEPS_NS {

const string &NOINDENT;

// maybe a template would be better, but so far looks easier
// with a macro

#define GEN_HEXDUMP(dest_type) \
void hexdump(dest_type dest, const void *bytes, size_t n, const char *indent) \
{ \
	const int LINELEN = 16; /* print so many bytes per line */ \
	const unsigned char *p = (const unsigned char *)bytes; /* byte being printed */ \
	int lc = 0; /* count of bytes in this line */ \
	for (; n > 0; n--, lc++) { \
		if (lc == LINELEN) { \
			HD_PUTS("  ", dest); \
			p -= lc; \
			for (int j = 0; j < lc; j++, p++) { \
				HD_PUTC(isprint(*p)? *p : '.', dest); \
			} \
			HD_PUTC('\n', dest); \
			lc = 0; \
		} \
		if (lc == 0) { \
			HD_PRINTF(dest, "%s%08X  ", indent, (int)(p - ((const unsigned char *)bytes))); \
		} \
		if (lc == LINELEN/2) \
			HD_PUTC(' ', dest); \
		HD_PRINTF(dest, " %02X", *p++); \
	} \
	if (lc != 0) { /* fill the last line */ \
		if (lc <= LINELEN/2) \
			HD_PUTC(' ',  dest); \
		for (int j = lc; j < LINELEN; j++) \
			HD_PUTS("   ",  dest); \
 \
		HD_PUTS("  ", dest); \
		p -= lc; \
		for (int j = 0; j < lc; j++, p++) { \
			HD_PUTC(isprint(*p)? *p : '.', dest); \
		} \
		HD_PUTC('\n', dest); \
		HD_FLUSH(dest); \
	} \
}

// dump to file

#define HD_PUTS(what, dest) fputs(what, dest)
#define HD_PUTC(what, dest) putc(what, dest)
#define HD_PRINTF(dest, ...) fprintf(dest, __VA_ARGS__)
#define HD_FLUSH(dest) fflush(dest)

GEN_HEXDUMP(FILE *)

#undef HD_PUTS
#undef HD_PUTC
#undef HD_PRINTF
#undef HD_FLUSH

// dump appending to a string

#define HD_PUTS(what, dest) dest.append(what)
#define HD_PUTC(what, dest) dest.push_back(what)
#define HD_PRINTF(dest, ...) dest.append(strprintf(__VA_ARGS__))
#define HD_FLUSH(dest) 

GEN_HEXDUMP(string &)

#undef HD_PUTS
#undef HD_PUTC
#undef HD_PRINTF
#undef HD_FLUSH

}; // BICEPS_NS

