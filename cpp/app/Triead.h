//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A Triceps Thread.  It keeps together the Nexuses defined by the thread and
// is also used to track the state of the app initialization.

#ifndef __Triceps_Triead_h__
#define __Triceps_Triead_h__

#include <common/Common.h>
#include <pw/ptwrap2.h>

namespace TRICEPS_NS {

// Even though the class name is funny, it's still pronounced as "thread". :-)
// (I want to avoid the name conflicts with the word "thread" that is used all
// over the place). 
class Triead : public Mtarget
{
	friend class TrieadOwner;
	friend class App;
public:
	// No public constructor! Use App!

protected:
	// Called through App::makeThriead().
	// @param name - Name of this thread (within the App).
	Triead(const string &name);
	
protected:
	// The initialization is done in two stages:
	// 1. Construction: the thread defines its own nexuses and locates
	// the nexuses of other threads (in any order), performs connections
	// between them, and of course initializes its internals. After it
	// reports itself constructed, it may not add any new nexuses nor
	// perform connections, and whatever it has defined becomes visible to
	// the other threads.
	// 2. Readiness: the thread waits for all the dependent threads to
	// become ready, before it declares itself ready. The whole application
	// becomes ready when all the threads in it are ready.
	//
	// Note that both stages imply the dependency graphs, but these graphs
	// may be very different. So far it looks more likely that these graphs
	// will have the opposite direction of the edges. The cycles are not
	// allowed in either of the graphs. The cycles get detected and 
	// mean the application initialization failure.
	
	// Flag/event: all the nexuses of this thread have been defined.
	// When this flag is set, the nexuses become visible.
	pw::oncevent constructed_;
	// Flag/event: the thread has been fully initialized, including
	// waiting on readiness of the other threads.
	pw::oncevent ready_;

	string name_; // name of the thread

private:
	Triead();
	Triead(const Triead &);
	void operator=(const Triead &);
};

// This is a special interface class that opens up the control API
// of the Triead to a single thread that owns it. The Triead and TrieadOwner
// creation is wrapped even farther, through App. The owner class is an Starget
// by design, it must be accessible to one thread only. 
class TrieadOwner : public Starget
{
	friend class App;
public:
	// Get the owned Triead.
	// Reasonably safe to assume that the TrieadOwner should be long-lived
	// and will survive any use of the returned pointer (at least until it
	// gets stored into another Autoref), and will hold the Triead in the
	// meantime. As a consequence, don't break this assumption, don't release
	// and destory the TrieadOwner until you're done with the returned pointer!
	Triead *get() const
	{
		return triead_.get();
	}

protected:
	// Called through App::makeThriead().
	// @param th - thread, whose control API to represent.
	TrieadOwner(Triead *th);

protected:
	Autoref<Triead> triead_;

private:
	TrieadOwner();
	TrieadOwner(const TrieadOwner &);
	void operator=(const TrieadOwner &);
};

}; // TRICEPS_NS

#endif // __Triceps_Triead_h__
