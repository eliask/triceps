//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// Helpers to join the Perl threads from the App.

#include <typeinfo>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "PerlTrieadJoin.h"

// ###################################################################################

using namespace TRICEPS_NS;

namespace TRICEPS_NS
{
namespace TricepsPerl 
{

PerlTrieadJoin *PerlTrieadJoin::make(const char *fname, const string &appname, const string &tname, SV *joiner, SV *thr)
{
	Onceref<PerlCallback> cb = new PerlCallback();
	if (!cb->setCode(joiner, fname)) {
		throw Exception::f("%s: joiner must be a reference to Perl function", fname);
	}
	cb->appendArg(thr);
	fprintf(stderr, "XXX PerlTrieadJoin::make thr_arg=%s\n", SvPV_nolen(thr));
	fprintf(stderr, "XXX PerlTrieadJoin::make thr=%s\n", SvPV_nolen(cb->args_[0]));

	return new PerlTrieadJoin(appname, tname, cb);
}

PerlTrieadJoin::PerlTrieadJoin(const string &appname, const string &tname, Onceref<PerlCallback> cb):
	appname_(appname),
	tname_(tname),
	cb_(cb)
{ }

void PerlTrieadJoin::join()
{
	dSP;

	fprintf(stderr, "XXX PerlTrieadJoin::join thr=%s\n", SvPV_nolen(cb_->args_[0]));

	PerlCallbackStartCall(cb_);
	XPUSHs(sv_2mortal(newSViv(99)));
	XPUSHs(sv_2mortal(newSViv(88)));
	PerlCallbackDoCall(cb_);
	callbackSuccessOrThrow("Detected in the application '%s' thread '%s' join.", appname_.c_str(), tname_.c_str());
}

}; // Triceps::TricepsPerl
}; // Triceps
