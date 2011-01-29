//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Helper functions working with strings

#include <common/StringUtil.h>
#include <ctype.h>

namespace BICEPS_NS {

const string &NOINDENT;

void hexdump(FILE *dest, const void *bytes, size_t n, const char *indent)
{
	const int LINELEN = 16; // print so many bytes per line
	const unsigned char *p = (const unsigned char *)bytes; // byte being printed
	int lc = 0; // count of bytes in this line
	for (; n > 0; n--, lc++) {
		if (lc == LINELEN) {
			fputs("  ", dest);
			p -= lc;
			for (int j = 0; j < lc; j++, p++) {
				putc(isprint(*p)? *p : '.', dest);
			}
			putc('\n', dest);
			lc = 0;
		}
		if (lc == 0) {
			fprintf(dest, "%s%08X  ", indent, (int)(p - ((const unsigned char *)bytes)));
		}
		if (lc == LINELEN/2)
			putc(' ', dest);
		fprintf(dest, " %02X", *p++);
	}
	if (lc != 0) { // fill the last line
		if (lc <= LINELEN/2)
			putc(' ',  dest);
		for (int j = lc; j < LINELEN; j++)
			fputs("   ",  dest);

		fputs("  ", dest);
		p -= lc;
		for (int j = 0; j < lc; j++, p++) {
			putc(isprint(*p)? *p : '.', dest);
		}
		putc('\n', dest);
		fflush(dest);
	}
}

}; // BICEPS_NS

