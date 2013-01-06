//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A Triceps Thread.  It keeps together the Nexuses defined by the thread and
// is also used to track the state of the app initialization.

#ifndef __Triceps_Triead_h__
#define __Triceps_Triead_h__

#include <pw/ptwrap2.h>
#include <common/Common.h>
#include <sched/Unit.h>

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

	~Triead();

	// Get the name
	const string &getName() const
	{
		return name_;
	}

	// Check if all the nexuses have been constructed.
	// Not const since the value might change between the calls,
	// if marked by the owner of this thread.
	bool isConstructed();

	// Check if all the connections have been completed and the
	// thread is ready to run.
	// Not const since the value might change between the calls,
	// if marked by the owner of this thread.
	bool isReady();

protected:
	// Called through App::makeThriead().
	// @param name - Name of this thread (within the App).
	Triead(const string &name);

	// Clear all the direct or indirect references to the other threads.
	// Called by the App at the destruction time.
	void clear();
	
	// The TrieadOwner API
	// {

	// Mark that the thread has constructed and exported all of its
	// nexuses.
	void markConstructed();

	// Mark that the thread has completed all its connections and
	// is ready to run. This also implies Constructed, and can be
	// used to set both flags at once.
	void markReady();
	// }
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

	string name_; // name of the thread, read-only

private:
	Triead();
	Triead(const Triead &);
	void operator=(const Triead &);
};

// This is a special interface class that opens up the control API
// of the Triead to a single thread that owns it. The Triead and TrieadOwner
// creation is wrapped even farther, through App. The owner class is an Starget
// by design, it must be accessible to one thread only. 
//
// Also includes all the control information that should not be visible
// from outside the owner thread.
class TrieadOwner : public Starget
{
	friend class App;
public:
	// The list of units in this thread, also determines their predictable
	// scheduling order.
	typedef list<Autoref<Unit> > UnitList;

	// The constructor is protected, called through App.
	// The destruction clears labels in all the thread's units.
	~TrieadOwner();

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

	// Get the main unit that get created with the thread and shares its name.
	// Assumes that TrieadOwner won't be destroyed while the result is used.
	Unit *unit() const
	{
		return mainUnit_;
	}

	// Add a unit to the thread, it's OK if it has been already added 
	// (extra addition will be ignored).
	// There is no easy way to find it back other than going through the
	// list of all the known units, so keep your own reference too.
	// @param u - unit to register.
	void addUnit(Autoref<Unit> u);

	// Forget a unit and remove it from the list.
	// The main unit can not be forgotten.
	// @param u - unit to forget
	// @return - true if unit was successfully forgotten, false if the unit was
	//     not known or is the main unit
	bool forgetUnit(Unit *u);

	// Get the list of all the units, in the order they were added.
	// This includes the main unit in the first position.
	const UnitList &listUnits() const
	{
		return units_;
	}

	// Mark that the thread has constructed and exported all of its
	// nexuses.
	void markConstructed()
	{
		triead_->markConstructed();
	}

	// Mark that the thread has completed all its connections and
	// is ready to run. This also implies Constructed, and can be
	// used to set both flags at once.
	void markReady()
	{
		triead_->markReady();
	}

protected:
	// Called through App::makeTriead().
	// Creates the thread's "main" same-named unit.
	// @param th - thread, whose control API to represent.
	TrieadOwner(Triead *th);

protected:
	Autoref<Triead> triead_;
	Autoref<Unit> mainUnit_; // the main unit, created with the thread
	UnitList units_; // units of this thread, includiong the main one

private:
	TrieadOwner();
	TrieadOwner(const TrieadOwner &);
	void operator=(const TrieadOwner &);
};

}; // TRICEPS_NS

#endif // __Triceps_Triead_h__
