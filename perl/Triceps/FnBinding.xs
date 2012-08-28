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


// Build a binding from components.
// Throws an Exception on errors.
//
// @param funcName - name of the calling function, for error messages.
// @param name - name of the FnBinding object to create.
// @param u - unit for creation of labels in the FnBinding.
// @param fnr - function return to bind to.
// @param labels - definition of labels in the bindings (a Perl array of elements that are
//        either label objects or code snippets)
// @return - the creaed binding.
static Onceref<FnBinding> makeBinding(const char *funcName, const string &name, Unit *u, FnReturn *fnr, AV *labels)
{
	Autoref<FnBinding> fbind = new FnBinding(name, fnr);

	// parse labels, and create labels around the code snippets
	int len = av_len(labels)+1; // av_len returns the index of last element
	if (len % 2 != 0) // 0 elements is OK
		throw Exception(strprintf("%s: option 'labels' must contain elements in pairs, has %d elements", funcName, len), false);
	for (int i = 0; i < len; i+=2) {
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

	return fbind;
}

MODULE = Triceps::FnBinding		PACKAGE = Triceps::FnBinding
###################################################################################

# The use is like this:
#
# $fnr = FnReturn->new(...);
# $bind = FnBinding->new(
#     name => "bind1", # used for diagnostics and the names of direct Perl labels
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
# $unit->callBound( # pushes all the bindings, does the call, pops
#     $rowop, # or $tray, or [ @rowops ]
#     $fnr => $bind, ...
# );
# ---
# Create a binding on the fly and call with it:
# FnBinding::call( # create and push/call/pop right away
#     name => "bind1", # used for diagnostics and the names of direct Perl labels
#     on => $fnr, # determines the type of return
#     unit => $unit, # needed only for the direct Perl code in labels or for auto-creation of rowops
#     labels => [
#         "name" => $label,
#         "name" => sub { ... }, # will directly create a Perl label
#     ]
#     rowop => $rowop, # what to call can be a rowop
#     tray => $tray, # or a tray
#     rowops => \@rowops, # or an array of rowops
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
				throw Exception(strprintf("%s: missing or empty mandatory option 'name'", funcName), false);
			if (fnr == NULL)
				throw Exception(strprintf("%s: missing mandatory option 'on'", funcName), false);
			if (labels == NULL)
				throw Exception(strprintf("%s: missing mandatory option 'labels'", funcName), false);

			fbind = makeBinding(funcName, name, u, fnr, labels);
		} TRICEPS_CATCH_CROAK;

		RETVAL = new WrapFnBinding(fbind);
	OUTPUT:
		RETVAL

# Args are the option pairs. The options are:
#
# XXX describe options, from the sample above
# Always returns 1.
int
call(...)
	CODE:
		static char funcName[] =  "Triceps::FnBinding::call";
		clearErrMsg();
		try {
			clearErrMsg();
			int len, i;
			Unit *u = NULL;
			AV *labels = NULL;
			string name;
			FnReturn *fnr = NULL;
			Rowop *rop = NULL;
			Tray *tray = NULL;
			AV *roparray = NULL; // array of rowops

			if (items % 2 != 0) {
				throw Exception::f("Usage: %s(optionName, optionValue, ...), option names and values must go in pairs", funcName);
			}
			for (int i = 0; i < items; i += 2) {
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
				} else if (!strcmp(optname, "rowop")) {
					rop = TRICEPS_GET_WRAP(Rowop, arg, "%s: option '%s'", funcName, optname)->get();
				} else if (!strcmp(optname, "tray")) {
					tray = TRICEPS_GET_WRAP(Tray, arg, "%s: option '%s'", funcName, optname)->get();
				} else if (!strcmp(optname, "rowops")) {
					roparray = GetSvArray(arg, "%s: option '%s'", funcName, optname);
				} else {
					throw Exception(strprintf("%s: unknown option '%s'", funcName, optname), false);
				}
			}

			if (u == NULL)
				throw Exception(strprintf("%s: missing mandatory option 'unit'", funcName), false);
			if (name.empty())
				throw Exception(strprintf("%s: missing or empty mandatory option 'name'", funcName), false);
			if (fnr == NULL)
				throw Exception(strprintf("%s: missing mandatory option 'on'", funcName), false);
			if (labels == NULL)
				throw Exception(strprintf("%s: missing mandatory option 'labels'", funcName), false);

			// the mutually exclusive ways to specify a rowop
			int rowop_spec = 0;
			if (rop != NULL) rowop_spec++;
			if (tray != NULL) rowop_spec++;
			if (roparray != NULL) rowop_spec++;

			if (rowop_spec != 1)
				throw Exception::f("%s: exactly 1 of options 'rowop', 'tray', 'rowops' must be specified, got %d of them.",
					funcName, rowop_spec);

			// create and set up the binding
			Autoref<FnBinding> fbind = makeBinding(funcName, name, u, fnr, labels);
			Autoref<AutoFnBind> ab = new AutoFnBind;
			ab->add(fnr, fbind);

			// call the labels
			if (roparray != NULL) {
				int len = av_len(roparray)+1; // av_len returns the index of last element
				for (int i = 0; i < len; i++) {
					SV *svop = *av_fetch(roparray, i, 0);
					u->call(TRICEPS_GET_WRAP(Rowop, svop, "%s: element %d of the option 'rowops' array", funcName, i)->get()); // not i+1 by design
				}
			} else if (rop) {
				u->call(rop);
			} else {
				u->callTray(tray);
			}

			// the bindings get popped
			try {
				ab->clear();
			} catch(Exception e) {
				throw Exception::f(e, "%s: error on popping the bindings:", funcName);
			}
		} TRICEPS_CATCH_CROAK;

		RETVAL = 1;
	OUTPUT:
		RETVAL

char *
getName(WrapFnBinding *self)
	CODE:
		clearErrMsg();
		RETVAL = (char *)self->get()->getName().c_str();
	OUTPUT:
		RETVAL


# Comparison of the underlying RowSetTypes.
int
equals(WrapFnBinding *self, SV *other)
	CODE:
		static char funcName[] =  "Triceps::FnReturn::equals";
		clearErrMsg();
		WrapFnReturn *wret;
		WrapFnBinding *wbind;
		try {
			TRICEPS_GET_WRAP2(FnReturn, wret, FnBinding, wbind, other, "%s: argument", funcName);
		} TRICEPS_CATCH_CROAK;
		if (wret)
			RETVAL = self->get()->equals(wret->get());
		else
			RETVAL = self->get()->equals(wbind->get());
	OUTPUT:
		RETVAL

int
match(WrapFnBinding *self, SV *other)
	CODE:
		static char funcName[] =  "Triceps::FnReturn::match";
		clearErrMsg();
		WrapFnReturn *wret;
		WrapFnBinding *wbind;
		try {
			TRICEPS_GET_WRAP2(FnReturn, wret, FnBinding, wbind, other, "%s: argument", funcName);
		} TRICEPS_CATCH_CROAK;
		if (wret)
			RETVAL = self->get()->match(wret->get());
		else
			RETVAL = self->get()->match(wbind->get());
	OUTPUT:
		RETVAL
