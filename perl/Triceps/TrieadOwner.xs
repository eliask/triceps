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

		bool testfail = false;
		if (SvOK(tid) // check only if not undef
		&& !SvIOK(tid)) {
			// a special hidden case to test the failure handling
			if (SvPOK(tid) && !strcmp(SvPV_nolen(tid), "__test_fail__"))
				testfail = true;
			else
				croak("%s: tid argument must be either an int or an undef", funcName);
		}

		RETVAL = NULL; // shut up the compiler
		try { do {
			Autoref<App> appv;
			parseApp(funcName, "app", app, appv);
			string tn(tname);
			Autoref<TrieadOwner> to = appv->makeTriead(tn, fragname);
			PerlTrieadJoin *tj = new PerlTrieadJoin(appv->getName(), tname, 
				SvIOK(tid)? SvIV(tid): -1, testfail);
			to->fileInterrupt_ = tj->fileInterrupt();
			appv->defineJoin(tn, tj);
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

int
isRqDead(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		RETVAL = self->get()->isRqDead();
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

#// Creates and exports a Nexus.
#// It can be called only until the thread is marked as constructed, afterwards it
#// will confess.
#//
#// Options:
#// 
#// name => $n
#// Name of the nexus, it will be used both as the export name and the
#// local name.
#//
#// labels => [ 
#//   name => $rowType,
#//   name => $fromLabel,
#// ]
#// Defines the labels similarly to FnReturn in a referenced array. The array contains
#// the pairs of (label_name, label_definition). The definition may be either
#// a RowType, and then a label of this row type will be created, or a Label,
#// and then a label of the same row type will be created and chained from that
#// original label. The created label objects can be later found from Facets, and used
#// like normal labels, by chaining them or sending rowops to them (but
#// chaining _from_ them is probably not the best idea, although it works anyway).
#// At least one definition pair must be present (if you don't need any, you
#// can always explicitly define _BEGIN_ and/or _END_ as placeholders).
#//
#// The labels are used to construct an implicit FnReturn in the current
#// thread's main unit, and this is the FnReturn that will be visible in the
#// Facet that gets imported back. If the import mode is "none", the FnReturn
#// will still be constructed and then abandoned (and freed by the reference count
#// going to 0, as usual). The labels used as $fromLabel must always belong to
#// the thread's main unit.
#//
#// XXX add an option "unit" to allow specifying the alternative units?
#//
#// rowTypes => [ 
#//   name => $rowType,
#// ]
#// Defines the row types exported in this Nexusm also as a referenced array
#// of name-value pairs. (Optional and may be empty).
#//
#// tableTypes => [ 
#//   name => $tableType,
#// ]
#// Defines the row types exported in this Nexusm also as a referenced array
#// of name-value pairs. (Optional and may be empty).
#//
#// reverse => 0/1
#// Flag: this Nexus goes in the reverse direction. (default: 0)
#//
#// queueLimit => $number
#// Defines the size limit after which the writes to the queue of this Nexus block.
#// In reality because of the double-buffering the queue may contain up to
#// twice that many trays before the future writes block. (Optional, the
#// default is whatever picked by the C++ code in Facet::DEFAULT_QUEUE_LIMIT, 500 or so).
#//
#// import => $importType
#// A string value, essentially an enum, determining how this Nexus gets
#// immediately imported back into this thread. The supported values are:
#//   reader (or anything starting from "read") - import for reading
#//   writer (or anything starting from "write") - import for writing
#//   none (or anything starting from "no") - do not import
#// The upper/lowercase doesn't matter. 
#//
#// @returns - if the nexus is immediately imported, a Facet for this nexus,
#//          or undef if not imported
#//
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
			AV *rowTypes = NULL;
			AV *tableTypes = NULL;
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
				} else if (!strcmp(optname, "rowTypes")) {
					rowTypes = GetSvArray(arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "tableTypes")) {
					tableTypes = GetSvArray(arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "reverse")) {
					reverse = SvTRUE(arg);
				} else if (!strcmp(optname, "queueLimit")) {
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

			if (rowTypes) {
				len = av_len(rowTypes)+1; // av_len returns the index of last element
				for (i = 0; i < len; i+=2) {
					SV *svname, *svval;
					svname = *av_fetch(rowTypes, i, 0);
					svval = *av_fetch(rowTypes, i+1, 0);

					string elname;
					GetSvString(elname, svname, "%s: option 'rowTypes' element %d name", funcName, i+1);

					RowType *rt = TRICEPS_GET_WRAP(RowType, svval, 
						"%s: in option 'rowTypes' element %d with name '%s'", funcName, i/2+1, SvPV_nolen(svname)
					)->get();

					fa->exportRowType(elname, rt);
				}
			}

			if (tableTypes) {
				len = av_len(tableTypes)+1; // av_len returns the index of last element
				for (i = 0; i < len; i+=2) {
					SV *svname, *svval;
					svname = *av_fetch(tableTypes, i, 0);
					svval = *av_fetch(tableTypes, i+1, 0);

					string elname;
					GetSvString(elname, svname, "%s: option 'tableTypes' element %d name", funcName, i+1);

					TableType *tt = TRICEPS_GET_WRAP(TableType, svval, 
						"%s: in option 'tableTypes' element %d with name '%s'", funcName, i/2+1, SvPV_nolen(svname)
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

#// Imports a Nexus.
#//
#// Options:
#// 
#// from => "$t/$n"
#// Identifier of the nexus to import, consisting of two parts separated
#// by a slash:
#//   * thread name
#//   * nexus name
#// The nexus name will also be used as the name of the local facet,
#// unless overridden by the option "as". 
#// The reason for slash separator is that normally both the thread name and
#// the nexus name parts may contain further components separated by dots, and
#// a different separator allows to find the boundary between them. If a dot
#// were used, in "a.b.c" would be impossible to say, does it mean the thread
#// "a" and nexus "b.c" in it, or thread "a.b" and nexus "c"? However
#// "a/b.c" or "a.b/c" have no such ambiguity.
#// Mutually exclusive with options "fromTriead" and "fromNexus".
#// 
#// fromTriead => $t
#// fromNexus => $n
#// The alternative way to specify the source thread and nexus as separate
#// components. Both options must be present or absent at the same time.
#// Mutually exclusive with "from".
#// 
#// as => $name
#// Specifies an override name for the local facet. Similar to the SQL clause AS.
#// (optional, default is to reuse the nexus name).
#// 
#// import => $importType
#// A string value, essentially an enum, determining how this Nexus gets
#// imported. The supported values are the same as for makeNexus (except "none",
#// since there is no point in a no-op import):
#//   reader (or anything starting from "read") - import for reading
#//   writer (or anything starting from "write") - import for writing
#// The upper/lowercase doesn't matter. 
#// 
#// immed => 0/1
#// Flag: do not wait for the exporter thread to be fully constructed.
#// Waiting synchronizes with the exporter and prevents a race of an import
#// attempt trying to find a nexus before it is made and failing. However
#// if two threads are waiting for each other, it becomes a deadlock that
#// gets caught on timeout and aborts the App. The immediate import allows
#// to avoid such deadlocks for the circular topologies with helper threads.
#// For example,
#//   thread A creates the nexus O;
#//   thread A creates the helper thread B and tells it to import the nexus A/O for
#//   its input immediately and create the nexus R for result;
#//   thread A requests (normal) import of the nexus B/R and falls asleep because B is not constructed yet;
#//     thread B starts running;
#//     thread B imports the nexus A/O immediately and succeeds;
#//     thread B defines its result nexus R;
#//     thread B defines marks itself as constructed and ready;
#//   thread A wakes up after B is constructed, finds the nexus B/R and completes its import;
#//   then thread A can complete its initialization, export other nexuses etc.
#// (default: 0, except if importing from itself)
#//
#// @returns - the newly imported Facet; if the same Nexus was already imported, will
#//   return the same facet instead of creating a new one (importing the same Nexus
#//   for both reading and writing is an error and will fail)
#//
WrapFacet *
importNexus(WrapTrieadOwner *self, ...)
	CODE:
		static char funcName[] =  "Triceps::TrieadOwner::importNexus";
		static char CLASS[] = "Triceps::Facet";
		clearErrMsg();
		TrieadOwner *to = self->get();
		RETVAL = NULL;
		try { do {
			int len, i;
			// Unit *u = NULL;
			AV *labels = NULL;
			AV *rowTypes = NULL;
			AV *tableTypes = NULL;
			string from;
			string fromTriead;
			string fromNexus;
			string as;
			string import; // the import type
			bool immed = false;
			bool writer;

			if (items % 2 != 1)
				throw Exception::f("Usage: %s(self, optionName, optionValue, ...), option names and values must go in pairs", funcName);

			for (int i = 1; i < items; i += 2) {
				const char *optname = (const char *)SvPV_nolen(ST(i));
				SV *arg = ST(i+1);
				if (!strcmp(optname, "from")) {
					GetSvString(from, arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "fromTriead")) {
					GetSvString(fromTriead, arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "fromNexus")) {
					GetSvString(fromNexus, arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "as")) {
					GetSvString(as, arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "import")) {
					GetSvString(import, arg, "%s: option '%s'", funcName, optname);
				} else if (!strcmp(optname, "immed")) {
					immed = SvTRUE(arg);
				} else {
					throw Exception::f("%s: unknown option '%s'", funcName, optname);
				}
			}

			if (from.empty() && fromNexus.empty())
				throw Exception::f("%s: one of options 'from' or 'fromNexus' must be not empty", funcName);
			if (fromTriead.empty() ^ fromNexus.empty())
				throw Exception::f("%s: options 'fromTriead' and 'fromNexus' must be both either empty or not", funcName);

			if (!from.empty()) {
				// break up into the Triead and Nexus parts
				size_t slash = from.find('/');
				if (slash == string::npos)
					throw Exception::f("%s: option 'from' must contain the thread and nexus names separated by '/', got '%s'", funcName, from.c_str());
				fromTriead = from.substr(0, slash);
				fromNexus = from.substr(slash + 1);
				if (fromTriead.empty())
					throw Exception::f("%s: empty thread name part in option 'from' (containing '%s')", funcName, from.c_str());
				if (fromNexus.empty())
					throw Exception::f("%s: empty nexus name part in option 'from' (containing '%s')", funcName, from.c_str());
			}

			std::transform(import.begin(), import.end(), import.begin(), ::tolower);
			if (import.compare(0, 5, "write") == 0) {
				writer = true;
			} else if (import.compare(0, 4, "read") == 0) {
				writer = false;
			} else {
				throw Exception::f("%s: the option 'import' must have the value one of 'writer', 'reader'; got '%s'", funcName, import.c_str());
			}

			Autoref<Facet> fa;
			try {
				fa = to->importNexus(fromTriead, fromNexus, as, writer, immed);
			} catch (Exception e) {
				throw Exception(e, strprintf("%s: invalid arguments:", funcName));
			}

			RETVAL = new WrapFacet(fa);
		} while(0); } TRICEPS_CATCH_CROAK;

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

int
flushWriters(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		RETVAL = 0;
		try { do {
			RETVAL = self->get()->flushWriters();
		} while(0); } TRICEPS_CATCH_CROAK;
	OUTPUT:
		RETVAL

void
requestMyselfDead(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		TrieadOwner *to = self->get();
		try { do {
			to->requestMyselfDead();
		} while(0); } TRICEPS_CATCH_CROAK;

#// XXX maybe add a version of nextXtray() and mainLoop() that calls
#// a given label after each iteration, before flushWriters()?
int
nextXtray(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		RETVAL = 0;
		try { do {
			RETVAL = self->get()->nextXtray();
		} while(0); } TRICEPS_CATCH_CROAK;
	OUTPUT:
		RETVAL

int
nextXtrayNoWait(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		RETVAL = 0;
		try { do {
			RETVAL = self->get()->nextXtrayNoWait();
		} while(0); } TRICEPS_CATCH_CROAK;
	OUTPUT:
		RETVAL

void
mainLoop(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		try { do {
			self->get()->mainLoop();
		} while(0); } TRICEPS_CATCH_CROAK;

bool
isRqDrain(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		RETVAL = 0;
		try { do {
			RETVAL = self->get()->isRqDrain();
		} while(0); } TRICEPS_CATCH_CROAK;
	OUTPUT:
		RETVAL

void
requestDrainShared(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		try { do {
			self->get()->requestDrainShared();
		} while(0); } TRICEPS_CATCH_CROAK;

void
requestDrainExclusive(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		try { do {
			self->get()->requestDrainExclusive();
		} while(0); } TRICEPS_CATCH_CROAK;

void
waitDrain(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		try { do {
			self->get()->waitDrain();
		} while(0); } TRICEPS_CATCH_CROAK;

#// checks whether the app is drained, not just this thread!
bool
isDrained(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		RETVAL = 0;
		try { do {
			RETVAL = self->get()->isDrained();
		} while(0); } TRICEPS_CATCH_CROAK;
	OUTPUT:
		RETVAL

void
drainShared(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		try { do {
			self->get()->drainShared();
		} while(0); } TRICEPS_CATCH_CROAK;

void
drainExclusive(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		try { do {
			self->get()->drainExclusive();
		} while(0); } TRICEPS_CATCH_CROAK;

void
undrain(WrapTrieadOwner *self)
	CODE:
		clearErrMsg();
		try { do {
			self->get()->undrain();
		} while(0); } TRICEPS_CATCH_CROAK;

#// XXX add addUnit() etc
#// XXX add interruption of the file reads
#// in the thread handler define a confess wrapper
