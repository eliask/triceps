#
# This file is a part of Biceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The wrapper for IndexType.

MODULE = Biceps		PACKAGE = Biceps::IndexType
###################################################################################

# create a HashedIndex
# options go in pairs  name => value 
WrapIndexType *
new_hashed(char *CLASS, ...)
	CODE:
		char funcName[] = "Biceps::IndexType::new_hashed";
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
new_fifo(char *CLASS, ...)
	CODE:
		char funcName[] = "Biceps::IndexType::new_fifo";
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
SV *
print(WrapIndexType *self)
	PPCODE:
		clearErrMsg();
		IndexType *ixt = self->get();
		string res;
		ixt->printTo(res);
		PUSHs(sv_2mortal(newSVpvn(res.c_str(), res.size())));
