//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for TrieadOwner.

#include <algorithm>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "TricepsOpt.h"
#include "PerlCallback.h"
#include "PerlApp.h"
#include "PerlTrieadJoin.h"
#include <app/TrieadOwner.h>

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


#// (there is also the implicit class parameter)
#// @param tid - thread id (as in $thr->tid()) where this TrieadOwner belongs, for joining 
#//        (or undef could be used for testing purposes but then you jave to join
#//        the thread yourself)
#// @param app - app object ref or name
#// @param tname - name of this thread in the app
#// @param fragname - name of the fragment in the app (or an empty string)
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

		RETVAL = new WrapApp(to->app());
	OUTPUT:
		RETVAL

WrapUnit *
unit(WrapTrieadOwner *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::Unit";

		clearErrMsg();
		TrieadOwner *to = self->get();

		RETVAL = new WrapUnit(to->unit());
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

#// a bunch of getters percolate from Triead

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

WrapFacet *
makeNexus(WrapTrieadOwner *self, ...)
	CODE:
		static char funcName[] =  "Triceps::TrieadOwner::makeNexus";
		static char CLASS[] = "Triceps::Facet";
		bool do_import = false; // whether to reimport the nexus after exporting it
		clearErrMsg();
		TrieadOwner *to = self->get();
		RETVAL = NULL;
		try { do {
			int len, i;
			// Unit *u = NULL;
			AV *labels = NULL;
			AV *row_types = NULL;
			AV *table_types = NULL;
			string name;
			bool reverse = false;
			int qlimit = -1; // "default"
			string import; // the import type
			bool writer;

			if (items % 2 != 1)
				throw Exception::f("Usage: %s(self, optionName, optionValue, ...), option names and values must go in pairs", funcName);

			for (int i = 1; i < items; i += 2) {
				const char *optname = (const char *)SvPV_nolen(ST(i));
				SV *arg = ST(i+1);
				if (!strcmp(optname, "name")) {
					GetSvString(name, arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "labels")) {
					labels = GetSvArray(arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "row_types")) {
					row_types = GetSvArray(arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "table_types")) {
					table_types = GetSvArray(arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "reverse")) {
					reverse = SvTRUE(arg);
				} else if (!strcmp(optname, "queue_limit")) {
					qlimit = GetSvInt(arg, "%s: option '%s'", funcName, optname);
					if (qlimit <= 0)
						throw Exception::f("%s: option '%s' must be >0, got %d", funcName, optname, qlimit);
				} else if (!strcmp(optname, "import")) {
					GetSvString(import, arg, "%s: option '%s'", funcName, optname);
				} else {
					throw Exception::f("%s: unknown option '%s'", funcName, optname);
				}
			}
#if 0 // { for now don't construct from FnReturn
			if (fret != NULL && labels != NULL)
				throw Exception::f("%s: options 'fn_return' and 'labels' are mutually exclusive", funcName);
			if (fret == NULL && labels == NULL)
				throw Exception::f("%s: one of the options 'fnreturn' or  'labels' must be present", funcName);
#endif // }
			Unit *u = to->unit();
			if (labels == NULL)
				throw Exception::f("%s: missing mandatory option 'labels'", funcName);
			checkLabelList(funcName, "labels", u, labels);

			if (name.empty())
				throw Exception::f("%s: must specify a non-empty name with option 'name'", funcName);

			std::transform(import.begin(), import.end(), import.begin(), ::tolower);
			if (import.compare(0, 5, "write") == 0) {
				writer = true; do_import = true;
			} else if (import.compare(0, 4, "read") == 0) {
				writer = false; do_import = true;
			} else if (import.compare(0, 2, "no") == 0) {
				writer = false; do_import = false;
			} else {
				throw Exception::f("%s: the option 'import' must have the value one of 'writer', 'reader', 'no'; got '%s'", funcName, import.c_str());
			}

			// start by building the FnReturn
			Autoref<FnReturn> fret = new FnReturn(u, name);

			addFnReturnLabels(funcName, "labels", u, labels, fret);

			// now make the Facet out it
			Autoref<Facet> fa = new Facet(fret, writer);
			fa->setReverse(reverse);
			if (qlimit > 0)
				fa->setQueueLimit(qlimit);

			if (row_types) {
				len = av_len(row_types)+1; // av_len returns the index of last element
				for (i = 0; i < len; i+=2) {
					SV *svname, *svval;
					svname = *av_fetch(row_types, i, 0);
					svval = *av_fetch(row_types, i+1, 0);

					string elname;
					GetSvString(elname, svname, "%s: option 'row_types' element %d name", funcName, i+1);

					RowType *rt = TRICEPS_GET_WRAP(RowType, svval, 
						"%s: in option 'row_types' element %d with name '%s'", funcName, i/2+1, SvPV_nolen(svname)
					)->get();

					fa->exportRowType(elname, rt);
				}
			}

			if (table_types) {
				len = av_len(table_types)+1; // av_len returns the index of last element
				for (i = 0; i < len; i+=2) {
					SV *svname, *svval;
					svname = *av_fetch(table_types, i, 0);
					svval = *av_fetch(table_types, i+1, 0);

					string elname;
					GetSvString(elname, svname, "%s: option 'table_types' element %d name", funcName, i+1);

					TableType *tt = TRICEPS_GET_WRAP(TableType, svval, 
						"%s: in option 'table_types' element %d with name '%s'", funcName, i/2+1, SvPV_nolen(svname)
					)->get();

					fa->exportTableType(elname, tt);
				}
			}

			try {
				to->exportNexus(fa, do_import); // this checks the facet for errors
			} catch (Exception e) {
				throw Exception(e, strprintf("%s: invalid arguments:", funcName));
			}

			if (do_import)
				RETVAL = new WrapFacet(fa);
		} while(0); } TRICEPS_CATCH_CROAK;

		if (!do_import)
			XSRETURN_UNDEF; // NOT an error, just nothing to return
	OUTPUT:
		RETVAL

#// same as Triead::exports(), for convenience
SV *
exports(WrapTrieadOwner *self)
	PPCODE:
		// for casting of return value
		static char CLASS[] = "Triceps::Nexus";
		clearErrMsg();
		Triead *t = self->get()->get();
		Triead::NexusMap m;
		t->exports(m);
		for (Triead::NexusMap::iterator it = m.begin(); it != m.end(); ++it) {
			XPUSHs(sv_2mortal(newSVpvn(it->first.c_str(), it->first.size())));

			SV *sub = newSV(0);
			sv_setref_pv( sub, CLASS, (void*)(new WrapNexus(it->second)) );
			XPUSHs(sv_2mortal(sub));
		}

#// unlike Triead::imports(), lists facets, which also have in them
#// the information of whether they are readers or writers, so no need
#// for the separate calls
SV *
imports(WrapTrieadOwner *self)
	PPCODE:
		// for casting of return value
		static char CLASS[] = "Triceps::Facet";
		clearErrMsg();
		TrieadOwner *to = self->get();
		TrieadOwner::FacetMap m;
		to->imports(m);
		for (TrieadOwner::FacetMap::iterator it = m.begin(); it != m.end(); ++it) {
			XPUSHs(sv_2mortal(newSVpvn(it->first.c_str(), it->first.size())));

			SV *sub = newSV(0);
			sv_setref_pv( sub, CLASS, (void*)(new WrapFacet(it->second)) );
			XPUSHs(sv_2mortal(sub));
		}

