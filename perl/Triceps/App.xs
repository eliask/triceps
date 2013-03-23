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

