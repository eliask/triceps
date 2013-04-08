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
	//
	// @param appname - name of the application, for error messages
	// @param tname - name of the thread owning this object, for error messages
	// @param tid - the Perl thread id, as in $thr->tid(); if tid is -1 then
	//        no join will be made but the file interruption will still work
	// @param istest - flag: false normally, true to artificially generate exceptions
	//        for a test of their catching
	PerlTrieadJoin(const string &appname, const string &tname, IV tid, bool istest = false);

	// Make 

	// from TrieadJoin
	virtual void join();
	virtual void interrupt();

protected:
	string appname_; // application name, for error messages
	IV tid_; // thread id (used since the thread object refs can't pass between the threads)
	bool testFail_; // flag: this is a test instance that generates exceptions

private:
	PerlTrieadJoin();
};


}; // Triceps::TricepsPerl
}; // Triceps


#endif // __TricepsPerl_PerlTrieadJoin_h__
