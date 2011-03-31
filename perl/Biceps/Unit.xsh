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

		Gadget::EnqMode em;
		// accept enqueueing mode as either number of name
		if (SvIOK(enqMode)) {
			int intem = SvIV(enqMode);
			switch(intem) { // if enum used directly, the compiler optimizes out "default"
			case Gadget::SM_SCHEDULE:
			case Gadget::SM_FORK:
			case Gadget::SM_CALL:
			case Gadget::SM_IGNORE:
				break;
			default:
				setErrMsg(strprintf("%s: unknown enqueuing mode integer %d", funcName, intem));
				XSRETURN_UNDEF;
				break;
			}
			em = (Gadget::EnqMode)intem;
		} else {
			const char *emname = SvPV_nolen(enqMode);
			if (!strcmp(emname, "SCHEDULE"))
				em = Gadget::SM_SCHEDULE;
			else if (!strcmp(emname, "FORK"))
				em = Gadget::SM_FORK;
			else if (!strcmp(emname, "CALL"))
				em = Gadget::SM_CALL;
			else if (!strcmp(emname, "IGNORE"))
				em = Gadget::SM_IGNORE;
			else {
				setErrMsg(strprintf("%s: unknown enqueuing mode string '%s', if integer was meant, it has to be cast", funcName, emname));
				XSRETURN_UNDEF;
			}
		}

		Autoref<Table> t = tbt->makeTable(unit->get(), em, name);
		if (t.isNull()) {
			setErrMsg(strprintf("%s: table type was not successfully initialized", funcName));
			XSRETURN_UNDEF;
		}
		RETVAL = new WrapTable(t);
	OUTPUT:
		RETVAL
