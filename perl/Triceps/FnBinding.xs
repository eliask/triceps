//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for FnBinding.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "TricepsOpt.h"
#include "PerlCallback.h"

MODULE = Triceps::FnBinding		PACKAGE = Triceps::FnBinding
###################################################################################

# The use is like this:
#
# $fnr = FnReturn->new(...);
# $bind = FnBinding->new(
#     name => "bind1", # used for the names of direct Perl labels
#     on => $fnr, # determines the type of return
#     unit => $unit, # needed only for the direct Perl code
#     labels => [
#         "name" => $label,
#         "name" => sub { ... }, # will directly create a Perl label
#     ]
# );
# $fnr->push($bind);
# $fnr->pop($bind);
# $fnr->pop();
# {
#     $auto = AutoFnBind->new($fnr => $bind, ...);
#     $unit->call(...);
# }
# ---
# FnBinding->call( # create and push/call/pop right away
#     name => "bind1", # used for the names of direct Perl labels
#     on => $fnr, # determines the type of return
#     unit => $unit, # needed only for the direct Perl code
#     labels => [
#         "name" => $label,
#         "name" => sub { ... }, # will directly create a Perl label
#     ]
#     rowop => $rowop, # what to call can be a rowop
#     label => $label, # or a label and a row
#     row => $row, # a row may be an actual row
#     rowHash => { ... }, # or a hash
#     rowHash => [ ... ], # either an actual hash or its array form
#     rowArray => [ ... ], # or an array of values
# );
# $unit->callBound( # pushes all the bindings, does the call, pops
#     $rowop, # or $tray, or [ @rowops ]
#     $fnr => $bind, ...
# );
#     
# 

void
DESTROY(WrapFnBinding *self)
	CODE:
		// warn("FnBinding destroyed!");
		delete self;

# check whether both refs point to the same object
int
same(WrapFnBinding *self, WrapFnBinding *other)
	CODE:
		clearErrMsg();
		FnBinding *f = self->get();
		FnBinding *of = other->get();
		RETVAL = (f == of);
	OUTPUT:
		RETVAL

# Args are the option pairs. The options are:
#
# XXX describe options, from the sample above
WrapFnBinding *
new(char *CLASS, ...)
	CODE:
		static char funcName[] =  "Triceps::FnBinding::new";
		Autoref<FnBinding> fbind;
		clearErrMsg();
		try {
			clearErrMsg();
			int len, i;
			Unit *u = NULL;
			AV *labels = NULL;
			string name;
			FnReturn *fnr = NULL;

			if (items % 2 != 1) {
				throw Exception("Usage: Triceps::FnBinding::new(CLASS, optionName, optionValue, ...), option names and values must go in pairs", false);
			}
			for (int i = 1; i < items; i += 2) {
				const char *optname = (const char *)SvPV_nolen(ST(i));
				SV *arg = ST(i+1);
				if (!strcmp(optname, "unit")) {
					u = TRICEPS_GET_WRAP(Unit, arg, "%s: option '%s'", funcName, optname)->get();
				} else if (!strcmp(optname, "name")) {
					GetSvString(name, arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "on")) {
					fnr = TRICEPS_GET_WRAP(FnReturn, arg, "%s: option '%s'", funcName, optname)->get();
				} else if (!strcmp(optname, "labels")) {
					labels = GetSvArray(arg, "%s: option '%s'", funcName, optname);
				} else {
					throw Exception(strprintf("%s: unknown option '%s'", funcName, optname), false);
				}
			}

			if (name.empty())
				throw Exception(strprintf("%s: missing mandatory option 'name'", funcName), false);
			if (fnr == NULL)
				throw Exception(strprintf("%s: missing mandatory option 'on'", funcName), false);
			if (labels == NULL)
				throw Exception(strprintf("%s: missing mandatory option 'labels'", funcName), false);

			fbind = new FnBinding(name, fnr);

			// parse labels, and create labels around the code snippets
			len = av_len(labels)+1; // av_len returns the index of last element
			if (len % 2 != 0) // 0 elements is OK
				throw Exception(strprintf("%s: option 'labels' must contain elements in pairs, has %d elements", funcName, len), false);
			for (i = 0; i < len; i+=2) {
				SV *svname, *svval;
				svname = *av_fetch(labels, i, 0);
				svval = *av_fetch(labels, i+1, 0);
				string entryname;

				GetSvString(entryname, svname, "%s: in option 'labels' element %d name", funcName, i/2+1);

				Autoref<Label> lb = GetSvLabelOrCode(svval, "%s: in option 'labels' element %d with name '%s'", 
					funcName, i/2+1, SvPV_nolen(svname));
				if (lb.isNull()) {
					// it's a code snippet, make a label
					if (u == NULL) {
						throw Exception(strprintf("%s: option 'unit' must be set to handle the code reference in option 'labels' element %d with name '%s'", 
							funcName, i/2+1, SvPV_nolen(svname)), false);
					}
					string lbname = name + "." + entryname;
					RowType *rt = fnr->getRowType(entryname);
					if (rt == NULL) {
						throw Exception(strprintf("%s: in option 'labels' element %d has an unknown return label name '%s'", 
							funcName, i/2+1, SvPV_nolen(svname)), false);
					}
					lb = PerlLabel::makeSimple(u, rt, lbname, svval, "%s: in option 'labels' element %d with name '%s'",
						funcName, i/2+1, SvPV_nolen(svname));
				}
				fbind->addLabel(entryname, lb, true);
			}
			try {
				fbind->checkOrThrow();
			} catch (Exception e) {
				throw Exception(e, strprintf("%s: invalid arguments:", funcName));
			}
		} TRICEPS_CATCH_CROAK;

		RETVAL = new WrapFnBinding(fbind);
	OUTPUT:
		RETVAL


