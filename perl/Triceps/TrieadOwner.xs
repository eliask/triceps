//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for TrieadOwner.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "PerlCallback.h"
#include "PerlApp.h"
#include "PerlTrieadJoin.h"
#include "app/TrieadOwner.h"

MODULE = Triceps::TrieadOwner		PACKAGE = Triceps::TrieadOwner
###################################################################################

int
CLONE_SKIP(...)
	CODE:
		RETVAL = 1;
	OUTPUT:
		RETVAL

void
DESTROY(WrapTrieadOwner *self)
	CODE:
		// TrieadOwner *to = self->get();
		// warn("TrieadOwner %s %p wrap %p destroyed!", to->get()->getName().c_str(), to, self);
		delete self;


# (there is also the implicit class parameter)
# @param tid - thread id (as in $thr->tid()) where this TrieadOwner belongs, for joining 
#        (or undef could be used for testing purposes but then you jave to join
#        the thread yourself)
# @param app - app object ref or name
# @param tname - name of this thread in the app
# @param fragname - name of the fragment in the app (or an empty string)
WrapTrieadOwner *
Triceps::TrieadOwner::new(SV *tid, SV *app, char *tname, char *fragname)
	CODE:
		static char funcName[] =  "Triceps::TrieadOwner::new";
		clearErrMsg();

		if (SvOK(tid) // check only if not undef
		&& !SvIOK(tid))
			croak("%s: tid argument must be either an int or an undef", funcName);

		RETVAL = NULL; // shut up the compiler
		try { do {
			Autoref<App> appv;
			parseApp(funcName, "app", app, appv);
			string tn(tname);
			Autoref<TrieadOwner> to = appv->makeTriead(tn, fragname);
			if (SvIOK(tid))
				appv->defineJoin(tn, new PerlTrieadJoin(appv->getName(), tname, SvIV(tid)));
			RETVAL = new WrapTrieadOwner(to);
		} while(0); } TRICEPS_CATCH_CROAK;
	OUTPUT:
		RETVAL

WrapApp *
app(WrapTrieadOwner *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::App";

		clearErrMsg();
		TrieadOwner *to = self->get();

		WrapApp *wa = new WrapApp(to->app());
		RETVAL = wa;
	OUTPUT:
		RETVAL

void
markConstructed(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		TrieadOwner *to = self->get();
		try { do {
			to->markConstructed();
		} while(0); } TRICEPS_CATCH_CROAK;

void
markReady(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		TrieadOwner *to = self->get();
		try { do {
			to->markReady();
		} while(0); } TRICEPS_CATCH_CROAK;

void
readyReady(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		TrieadOwner *to = self->get();
		try { do {
			to->readyReady();
		} while(0); } TRICEPS_CATCH_CROAK;

void
markDead(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		TrieadOwner *to = self->get();
		try { do {
			to->markDead();
		} while(0); } TRICEPS_CATCH_CROAK;

void
abort(WrapTrieadOwner *self, char *msg)
	CODE:
		clearErrMsg();
		TrieadOwner *to = self->get();
		try { do {
			to->abort(msg);
		} while(0); } TRICEPS_CATCH_CROAK;

WrapTriead *
get(WrapTrieadOwner *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::Triead";

		clearErrMsg();
		TrieadOwner *to = self->get();

		WrapTriead *wa = new WrapTriead(to->get());
		RETVAL = wa;
	OUTPUT:
		RETVAL

# a bunch of getters percolate from Triead

char *
getName(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		Triead *t = self->get()->get();
		RETVAL = (char *)t->getName().c_str();
	OUTPUT:
		RETVAL

char *
fragment(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		Triead *t = self->get()->get();
		RETVAL = (char *)t->fragment().c_str();
	OUTPUT:
		RETVAL

int
isConstructed(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		Triead *t = self->get()->get();
		RETVAL = t->isConstructed();
	OUTPUT:
		RETVAL

int
isReady(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		Triead *t = self->get()->get();
		RETVAL = t->isReady();
	OUTPUT:
		RETVAL

int
isDead(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		Triead *t = self->get()->get();
		RETVAL = t->isDead();
	OUTPUT:
		RETVAL

int
isInputOnly(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		Triead *t = self->get()->get();
		RETVAL = t->isInputOnly();
	OUTPUT:
		RETVAL

void
makeNexusNoImport(WrapTrieadOwner *self, ...)
	CODE:
		static char funcName[] =  "Triceps::TrieadOwner::makeNexusNoImport";
		clearErrMsg();
		try { do {
			int len, i;
			FnReturn *fret = NULL;
			// Unit *u = NULL;
			AV *labels = NULL;
			AV *rowts = NULL;
			AV *tablets = NULL;
			string name;
			bool reverse = false;
			int qlimit = -1; // "default"

			if (items % 2 != 1)
				throw Exception::f("Usage: %s(self, optionName, optionValue, ...), option names and values must go in pairs", funcName);

			for (int i = 1; i < items; i += 2) {
				const char *optname = (const char *)SvPV_nolen(ST(i));
				SV *arg = ST(i+1);
				if (!strcmp(optname, "fn_return")) {
					fret = TRICEPS_GET_WRAP(FnReturn, arg, "%s: option '%s'", funcName, optname)->get();
				} else if (!strcmp(optname, "name")) {
					GetSvString(name, arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "labels")) {
					labels = GetSvArray(arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "row_types")) {
					rowts = GetSvArray(arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "table_types")) {
					tablets = GetSvArray(arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "reverse")) {
					reverse = SvTRUE(arg);
				} else if (!strcmp(optname, "queue_limit")) {
					qlimit = GetSvInt(arg, "%s: option '%s'", funcName, optname);
					if (qlimit <= 0)
						throw Exception::f("%s: option '%s' must be >0, got %d", funcName, optname, qlimit);
				} else {
					throw Exception::f("%s: unknown option '%s'", funcName, optname);
				}
			}
			if (fret != NULL && labels != NULL)
				throw Exception::f("%s: options 'fn_return' and 'labels' are mutually exclusive", funcName);
			if (fret == NULL && labels == NULL)
				throw Exception::f("%s: one of the options 'fnreturn' or  'labels' must be present", funcName);
		} while(0); } TRICEPS_CATCH_CROAK;

# XXX test all methods
