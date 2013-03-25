//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// Helpers to join the Perl threads from the App.
// XXX should they be moved into PerlApp.*?

// Include TricepsPerl.h before this one.

// ###################################################################################

#ifndef __TricepsPerl_PerlTrieadJoin_h__
#define __TricepsPerl_PerlTrieadJoin_h__

#include "PerlCallback.h"
#include <app/TrieadJoin.h>

using namespace TRICEPS_NS;

namespace TRICEPS_NS
{
namespace TricepsPerl 
{

// The joiner for the Perl threads
class PerlTrieadJoin : public TrieadJoin
{
public:
	// Make the PerlTrieadJoin object.
	// May throw an Exception if the threads are not imported in Perl
	// (and this is the reason to why it can't be a constructor).
	//
	// @param appname - name of the application, for error messages
	// @param tname - name of the thread owning this object, for error messages
	// @param thr - the Perl thread object for joining, must be already checked that
	//        it's a valid thread object, threads::join will be called on it;
	//        this object will be referred in the callback
	// @return - the newly constructed PerlTrieadJoin object
	static PerlTrieadJoin *make(const string &appname, const string &tname, SV *thr);

	// from TrieadJoin
	virtual void join();
	// XXX add the interruption for the file reading in Perl

protected:
	// @param appname - name of the application, for error messages
	// @param tname - name of the thread owning this object, for error messages
	// @param cb - the call back object that performs the joining
	PerlTrieadJoin(const string &appname, const string &tname, Onceref<PerlCallback> cb);

	string appname_; // application name, for error messages
	string tname_; // thread name, for error messages
	Autoref<PerlCallback> cb_; // the join() callback

private:
	PerlTrieadJoin();
};


}; // Triceps::TricepsPerl
}; // Triceps


#endif // __TricepsPerl_PerlTrieadJoin_h__
