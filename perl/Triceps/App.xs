//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for App.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "PerlApp.h"
#include "app/App.h"

MODULE = Triceps::App		PACKAGE = Triceps::App
###################################################################################

int
CLONE_SKIP(...)
	CODE:
		RETVAL = 1;
	OUTPUT:
		RETVAL

void
DESTROY(WrapApp *self)
	CODE:
		App *app = self->get();
		// warn("App %s %p wrap %p destroyed!", app->getName().c_str(), app, self);
		delete self;


WrapApp *
make(char *name)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::App";

		clearErrMsg();
		RETVAL = NULL; // shut up the warning

		try { do {
			Autoref<App> app ;
			app = App::make(name);
			// warn("Created app %s %p wrap %p", name, app.get(), wa);
			RETVAL = new WrapApp(app);
		} while(0); } TRICEPS_CATCH_CROAK;

	OUTPUT:
		RETVAL

WrapApp *
find(char *name)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::App";

		clearErrMsg();
		RETVAL = NULL; // shut up the warning

		try { do {
			Autoref<App> app ;
			app = App::find(name);
			RETVAL = new WrapApp(app);
		} while(0); } TRICEPS_CATCH_CROAK;

	OUTPUT:
		RETVAL

# This works both as an object method on an object, or as
# a class method with an object or name argument
void
drop(SV *app)
	CODE:
		static char funcName[] =  "Triceps::App::drop";
		clearErrMsg();
		try { do {
			Autoref<App> appv;
			parseApp(funcName, "app", app, appv);
			App::drop(appv);
		} while(0); } TRICEPS_CATCH_CROAK;

SV *
listApps()
	PPCODE:
		// for casting of return value
		static char CLASS[] = "Triceps::App";

		clearErrMsg();
		App::Map m;
		App::listApps(m);
		for (App::Map::iterator it = m.begin(); it != m.end(); ++it) {
			XPUSHs(sv_2mortal(newSVpvn(it->first.c_str(), it->first.size())));

			SV *sub = newSV(0);
			sv_setref_pv( sub, CLASS, (void*)(new WrapApp(it->second)) );
			XPUSHs(sv_2mortal(sub));
		}

# check whether both refs point to the same object
int
same(WrapApp *self, WrapApp *other)
	CODE:
		clearErrMsg();
		App *a1 = self->get();
		App *a2 = other->get();
		RETVAL = (a1 == a2);
	OUTPUT:
		RETVAL

char *
getName(WrapApp *self)
	CODE:
		clearErrMsg();
		App *a = self->get();
		RETVAL = (char *)a->getName().c_str();
	OUTPUT:
		RETVAL

void
declareTriead(WrapApp *self, char *tname)
	CODE:
		clearErrMsg();
		App *a = self->get();
		try { do {
			a->declareTriead(tname);
		} while(0); } TRICEPS_CATCH_CROAK;

int
harvestOnce(WrapApp *self)
	CODE:
		clearErrMsg();
		App *a = self->get();
		RETVAL = 0;
		try { do {
			RETVAL = (int)a->harvestOnce();
		} while(0); } TRICEPS_CATCH_CROAK;
	OUTPUT:
		RETVAL

# Options:
#
# die_on_abort => int
# Flag: if the App abort has been detected, will die after it disposes
# of the App. Analog of the C++ flag throwAbort. Default: 1.
#
void
harvester(WrapApp *self, ...)
	CODE:
		static char funcName[] =  "Triceps::App::harvester";
		clearErrMsg();
		App *a = self->get();
		try { do {
			bool throwAbort = true;

			if (items % 2 != 1) {
				throw Exception::f("Usage: %s(app, optionName, optionValue, ...), option names and values must go in pairs", funcName);
			}
			for (int i = 1; i < items; i += 2) {
				const char *optname = (const char *)SvPV_nolen(ST(i));
				SV *arg = ST(i+1);
				if (!strcmp(optname, "die_on_abort")) {
					throwAbort = SvTRUE(arg);
				} else {
					throw Exception::f("%s: unknown option '%s'", funcName, optname);
				}
			}

			a->harvester(throwAbort);
		} while(0); } TRICEPS_CATCH_CROAK;
