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


WrapTrieadOwner *
Triceps::TrieadOwner::new(char *appname, char *tname, char *fragname)
	CODE:
		clearErrMsg();

		RETVAL = NULL; // shut up the compiler
		try { do {
			Autoref<App> app = App::find(appname);
			Autoref<TrieadOwner> to = app->makeTriead(tname, fragname);
			// XXX add a TrieadJoin
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
		to->markConstructed();

void
markReady(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		TrieadOwner *to = self->get();
		to->markReady();

void
readyReady(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		TrieadOwner *to = self->get();
		to->readyReady();

void
markDead(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		TrieadOwner *to = self->get();
		to->markDead();

void
abort(WrapTrieadOwner *self, char *msg)
	CODE:
		clearErrMsg();
		TrieadOwner *to = self->get();
		to->abort(msg);

