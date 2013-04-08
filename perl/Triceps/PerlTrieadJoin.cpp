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

PerlTrieadJoin::PerlTrieadJoin(const string &appname, const string &tname, IV tid, bool istest):
	TrieadJoin(tname),
	appname_(appname),
	tid_(tid),
	testFail_(istest)
{ }

void PerlTrieadJoin::join()
{
	dSP;

	if (testFail_)
		throw Exception::f("PerlTrieadJoin::join test of error catching app '%s' thread '%s'",
			appname_.c_str(), name_.c_str());

	if (tid_ == -1)
		return;

	// Can not create cb when creating the object, since that is happening in a
	// different thread, and will cause a deadlock inside Perl when joining.
	Autoref<PerlCallback> cb = new PerlCallback;
	if (!cb->setCode(get_sv("Triceps::_JOIN_TID", 0), "")) {
		throw Exception::f("In the application '%s' thread '%s' join: can not find a function reference $Triceps::_JOIN_TID",
			appname_.c_str(), name_.c_str());;
	}

	PerlCallbackStartCall(cb);
	XPUSHs(sv_2mortal(newSViv(tid_)));
	PerlCallbackDoCall(cb);
	callbackSuccessOrThrow("Detected in the application '%s' thread '%s' join.", appname_.c_str(), name_.c_str());
}

void PerlTrieadJoin::interrupt()
{
	if (testFail_)
		throw Exception::f("PerlTrieadJoin::interrupt test of error catching app '%s' thread '%s'",
			appname_.c_str(), name_.c_str());
	else
		TrieadJoin::interrupt();
}

}; // Triceps::TricepsPerl
}; // Triceps
