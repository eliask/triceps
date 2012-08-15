//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for FnReturn.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "TricepsOpt.h"

MODULE = Triceps::FnReturn		PACKAGE = Triceps::FnReturn
###################################################################################

void
DESTROY(WrapFnReturn *self)
	CODE:
		// warn("FnReturn destroyed!");
		delete self;

# check whether both refs point to the same object
int
same(WrapFnReturn *self, WrapFnReturn *other)
	CODE:
		clearErrMsg();
		FnReturn *f = self->get();
		FnReturn *of = other->get();
		RETVAL = (f == of);
	OUTPUT:
		RETVAL

# Args are the option pairs. The options are:
#
# name => $name
# The name of the object.
#
# unit => $unit
# Defines the unit where this FnReturn belongs. If at least one of the labels in
# this object (see option "labels") is built by chaining from another label,
# the unit can be implicitly taken from there, and the option "unit" becomes
# optional. All the labels must belong to the same unit.
#
# labels => [ 
#   name => $rowType,
#   name => $fromLabel,
# ]
# Defines the labels of this return in a referenced array. The array contains
# the pairs of (label_name, label_definition). The definition may be either
# a RowType, and then a label of this row type will be created, or a Label,
# and then a label of the same row type will be created and chained from that
# original label. The created label objects can be later found, and used
# like normal labels, by chaining them or sending rowops to them (but
# chaining _from_ them is probably not the best idea, although it works anyway).
# At least one definition pair must be present.
WrapFnReturn *
new(char *CLASS, ...)
	CODE:
		static char funcName[] =  "Triceps::FnReturn::new";
		Autoref<FnReturn> fret;
		try {
			clearErrMsg();
			int len, i;
			Unit *u = NULL;
			AV *labels = NULL;
			string name;

			if (items % 2 != 1) {
				throw Exception("Usage: Triceps::FnReturn::new(CLASS, optionName, optionValue, ...), option names and values must go in pairs", false);
			}
			for (int i = 1; i < items; i += 2) {
				const char *optname = (const char *)SvPV_nolen(ST(i));
				SV *arg = ST(i+1);
				if (!strcmp(optname, "unit")) {
					u = TRICEPS_GET_WRAP(Unit, arg, "%s: option '%s'", funcName, optname)->get();
				} else if (!strcmp(optname, "name")) {
					GetSvString(name, arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "labels")) {
					labels = GetSvArray(arg, "%s: option '%s'", funcName, optname);
				} else {
					throw Exception(strprintf("%s: unknown option '%s'", funcName, optname), false);
				}
			}

			// parse and do the basic checks of the labels
			if (labels == NULL)
				throw Exception(strprintf("%s: missing mandatory option 'labels'", funcName), false);
			len = av_len(labels)+1; // av_len returns the index of last element
			if (len % 2 != 0 || len == 0)
				throw Exception(strprintf("%s: option 'labels' must contain elements in pairs, has %d elements", funcName, len), false);
			for (i = 0; i < len; i+=2) {
				SV *svname, *svval;
				WrapLabel *wl;
				WrapRowType *wrt;
				svname = *av_fetch(labels, i, 0);
				svval = *av_fetch(labels, i+1, 0);

				if (!SvPOK(svname))
					throw Exception(strprintf("%s: in option 'labels' element %d name must be a string", funcName, i/2+1), false);

				TRICEPS_GET_WRAP2(Label, wl, RowType, wrt, svval, "%s: in option 'labels' element %d with name '%s'", 
					funcName, i/2+1, SvPV_nolen(svname));

				if (wl != NULL) {
					Label *lb = wl->get();
					Unit *lbu = lb->getUnitPtr();

					if (lbu == NULL)
						throw Exception(strprintf("%s: a cleared label in option 'labels' element %d with name '%s' can not be used", 
							funcName, i/2+1, SvPV_nolen(svname)), false);

					if (u == NULL)
						u = lbu;
					else if (u != lbu)
						throw Exception(strprintf(
							"%s: label in option 'labels' element %d with name '%s' has a mismatching unit '%s', previously seen unit '%s'", 
							funcName, i/2+1, SvPV_nolen(svname), lbu->getName().c_str(), u->getName().c_str()), false);
				}
			}

			if (u == NULL)
				throw Exception(strprintf("%s: the unit can not be auto-deduced, must use an explicit option 'unit'", funcName), false);
			if (name.empty())
				throw Exception(strprintf("%s: must specify a non-empty name with option 'name'", funcName), false);

			// now finally start building the object
			fret = new FnReturn(u, name);

			len = av_len(labels)+1; // av_len returns the index of last element
			for (i = 0; i < len; i+=2) {
				SV *svname, *svval;
				WrapRowType *wrt;
				WrapLabel *wl;
				svname = *av_fetch(labels, i, 0);
				svval = *av_fetch(labels, i+1, 0);

				string lbname;
				GetSvString(lbname, svname, "%s: option 'label' element %d name", funcName, i+1);

				TRICEPS_GET_WRAP2(Label, wl, RowType, wrt, svval, "%s: in option 'labels' element %d with name '%s'", 
					funcName, i/2+1, SvPV_nolen(svname));

				if (wl != NULL) {
					Label *lb = wl->get();
					fret->addFromLabel(lbname, lb);
				} else {
					RowType *rt = wrt->get();
					fret->addLabel(lbname, rt);
				}
			}

			try {
				fret->initializeOrThrow(); // XXX could prepend a better error message
			} catch (Exception e) {
				throw Exception(e, strprintf("%s: invalid arguments:", funcName));
			}
		} TRICEPS_CATCH_CROAK;

		RETVAL = new WrapFnReturn(fret);
	OUTPUT:
		RETVAL

