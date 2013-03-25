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

PerlTrieadJoin *PerlTrieadJoin::make(const string &appname, const string &tname, SV *thr)
{
	Onceref<PerlCallback> cb = new PerlCallback();
	if (!cb->setCode(get_sv("threads::join", 0), "")) {
		throw Exception::f("Can not find the method threads::join(), probably the threads package is not imported.");
	}
	cb->appendArg(thr);
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

	PerlCallbackStartCall(cb_);
	PerlCallbackDoCall(cb_);
	callbackSuccessOrThrow("Detected in the application '%s' thread '%s' join.", appname_.c_str(), tname_.c_str());
}

}; // Triceps::TricepsPerl
}; // Triceps
