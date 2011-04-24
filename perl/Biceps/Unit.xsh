#
# This file is a part of Biceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The wrapper for Unit.

MODULE = Biceps		PACKAGE = Biceps::Unit
###################################################################################

void
DESTROY(WrapUnit *self)
	CODE:
		// warn("Unit destroyed!");
		delete self;


WrapUnit *
Biceps::Unit::new(char *name)
	CODE:
		clearErrMsg();

		RETVAL = new WrapUnit(new Unit(name));
	OUTPUT:
		RETVAL

WrapTable *
makeTable(WrapUnit *unit, WrapTableType *wtt, SV *enqMode, char *name)
	CODE:
		char funcName[] = "Biceps::Unit::makeTable";
		// for casting of return value
		static char CLASS[] = "Biceps::Table";

		clearErrMsg();
		TableType *tbt = wtt->get();

		int intem;
		// accept enqueueing mode as either number of name
		if (SvIOK(enqMode)) {
			intem = SvIV(enqMode);
			if (Gadget::emString(intem, NULL) == NULL) {
				setErrMsg(strprintf("%s: unknown enqueuing mode integer %d", funcName, intem));
				XSRETURN_UNDEF;
			}
			// em = (Gadget::EnqMode)intem;
		} else {
			const char *emname = SvPV_nolen(enqMode);
			intem = Gadget::stringEm(emname);
			if (intem == -1) {
				setErrMsg(strprintf("%s: unknown enqueuing mode string '%s', if integer was meant, it has to be cast", funcName, emname));
				XSRETURN_UNDEF;
			}
		}
		Gadget::EnqMode em = (Gadget::EnqMode)intem;

		Autoref<Table> t = tbt->makeTable(unit->get(), em, name);
		if (t.isNull()) {
			setErrMsg(strprintf("%s: table type was not successfully initialized", funcName));
			XSRETURN_UNDEF;
		}
		RETVAL = new WrapTable(t);
	OUTPUT:
		RETVAL

# XXX add the rest of methods
