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
#include "app/App.h"

MODULE = Triceps::App		PACKAGE = Triceps::App
###################################################################################

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
		Autoref<App> app ;

		try { do {
			app = App::make(name);
		} while(0); } TRICEPS_CATCH_CROAK;

		WrapApp *wa = new WrapApp(app);
		// warn("Created app %s %p wrap %p", name, app.get(), wa);
		RETVAL = wa;
	OUTPUT:
		RETVAL

WrapApp *
find(char *name)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::App";

		clearErrMsg();
		Autoref<App> app ;

		try { do {
			app = App::find(name);
		} while(0); } TRICEPS_CATCH_CROAK;

		RETVAL = new WrapApp(app);
	OUTPUT:
		RETVAL

void
drop(WrapApp *self)
	CODE:
		App::drop(self->get());

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

