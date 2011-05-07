//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for IndexType.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

MODULE = Triceps::IndexType		PACKAGE = Triceps::IndexType
###################################################################################

void
DESTROY(WrapIndexType *self)
	CODE:
		// warn("IndexType destroyed!");
		delete self;


# create a HashedIndex
# options go in pairs  name => value 
WrapIndexType *
newHashed(char *CLASS, ...)
	CODE:
		char funcName[] = "Triceps::IndexType::newHashed";
		clearErrMsg();

		Autoref<NameSet> key;

		if (items % 2 != 1) {
			setErrMsg(strprintf("Usage: %s(CLASS, optionName, optionValue, ...), option names and values must go in pairs", funcName));
			XSRETURN_UNDEF;
		}
		for (int i = 1; i < items; i += 2) {
			const char *opt = (const char *)SvPV_nolen(ST(i));
			SV *val = ST(i+1);
			if (!strcmp(opt, "key")) {
				if (!key.isNull()) {
					setErrMsg(strprintf("%s: option 'key' can not be used twice", funcName));
					XSRETURN_UNDEF;
				}
				key = parseNameSet(funcName, "key", val);
				if (key.isNull()) // error message already set
					XSRETURN_UNDEF;
			} else {
				setErrMsg(strprintf("%s: unknown option '%s'", funcName, opt));
				XSRETURN_UNDEF;
			}
		}

		if (key.isNull()) {
			setErrMsg(strprintf("%s: the required option 'key' is missing", funcName));
			XSRETURN_UNDEF;
		}

		RETVAL = new WrapIndexType(new HashedIndexType(key));
	OUTPUT:
		RETVAL

# create a FifoIndex
# options go in pairs  name => value 
WrapIndexType *
newFifo(char *CLASS, ...)
	CODE:
		char funcName[] = "Triceps::IndexType::newFifo";
		clearErrMsg();

		size_t limit = 0;
		bool jumping = false;

		if (items % 2 != 1) {
			setErrMsg(strprintf("Usage: %s(CLASS, optionName, optionValue, ...), option names and values must go in pairs", funcName));
			XSRETURN_UNDEF;
		}
		for (int i = 1; i < items; i += 2) {
			const char *opt = (const char *)SvPV_nolen(ST(i));
			SV *val = ST(i+1);
			if (!strcmp(opt, "limit")) { // XXX should it check for < 0?
				limit = SvIV(val); // may overflow if <0 but we don't care
			} else if (!strcmp(opt, "jumping")) {
				jumping = SvIV(val);
			} else {
				setErrMsg(strprintf("%s: unknown option '%s'", funcName, opt));
				XSRETURN_UNDEF;
			}
		}

		RETVAL = new WrapIndexType(new FifoIndexType(limit, jumping));
	OUTPUT:
		RETVAL

# print the description
# XXX add indenting?
SV *
print(WrapIndexType *self)
	PPCODE:
		clearErrMsg();
		IndexType *ixt = self->get();
		string res;
		ixt->printTo(res);
		PUSHs(sv_2mortal(newSVpvn(res.c_str(), res.size())));

# type comparisons
int
equals(WrapIndexType *self, WrapIndexType *other)
	CODE:
		clearErrMsg();
		IndexType *ixself = self->get();
		IndexType *ixother = other->get();
		RETVAL = ixself->equals(ixother);
	OUTPUT:
		RETVAL

int
match(WrapIndexType *self, WrapIndexType *other)
	CODE:
		clearErrMsg();
		IndexType *ixself = self->get();
		IndexType *ixother = other->get();
		RETVAL = ixself->match(ixother);
	OUTPUT:
		RETVAL

# check if leaf
int
isLeaf(WrapIndexType *self)
	CODE:
		clearErrMsg();
		IndexType *ixt = self->get();
		RETVAL = ixt->isLeaf();
	OUTPUT:
		RETVAL

# add a nested index
WrapIndexType *
addNested(WrapIndexType *self, char *subname, WrapIndexType *sub)
	CODE:
		char funcName[] = "Triceps::IndexType::addNested";
		// for casting of return value
		static char CLASS[] = "Triceps::IndexType";

		clearErrMsg();
		IndexType *ixt = self->get();

		if (ixt->isInitialized()) {
			setErrMsg(strprintf("%s: index is already initialized, can not add indexes any more", funcName));
			XSRETURN_UNDEF;
		}

		IndexType *ixsub = sub->get();
		// can't just return self because it will upset the refcount
		RETVAL = new WrapIndexType(ixt->addNested(subname, ixsub));
	OUTPUT:
		RETVAL

# find a nested index by name
WrapIndexType *
findNested(WrapIndexType *self, char *subname)
	CODE:
		char funcName[] = "Triceps::IndexType::findNested";
		// for casting of return value
		static char CLASS[] = "Triceps::IndexType";

		clearErrMsg();
		IndexType *ixt = self->get();
		IndexType *ixsub = ixt->findNested(subname);
		if (ixsub == NULL) {
			setErrMsg(strprintf("%s: unknown nested index '%s'", funcName, subname));
			XSRETURN_UNDEF;
		}
		RETVAL = new WrapIndexType(ixsub);
	OUTPUT:
		RETVAL

# get the first leaf sub-index
WrapIndexType *
getFirstLeaf(WrapIndexType *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::IndexType";

		clearErrMsg();
		IndexType *ixt = self->get();
		RETVAL = new WrapIndexType(ixt->getFirstLeaf());
	OUTPUT:
		RETVAL

# check if the type has been initialized
int
isInitialized(WrapIndexType *self)
	CODE:
		clearErrMsg();
		IndexType *ixt = self->get();
		RETVAL = ixt->isInitialized();
	OUTPUT:
		RETVAL

# XXX dealing with IndexId requires constants, so leave a lone for now...
