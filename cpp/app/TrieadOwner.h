//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The control interface and object for the Triceps Thread.

#ifndef __Triceps_TrieadOwner_h__
#define __Triceps_TrieadOwner_h__

#include <app/Triead.h>
#include <app/App.h>

namespace TRICEPS_NS {

// This is a special interface class that opens up the control API
// of the Triead to a single thread that owns it. The Triead and TrieadOwner
// creation is wrapped even farther, through App. The owner class is an Starget
// by design, it must be accessible to one thread only. 
//
// Also includes all the control information that should not be visible
// from outside the owner thread.
//
// And also includes a reference to the App. This allows to avoid the reference
// loops, with references going in the direction TrieadOwner->App->Triead.
//
// When the TrieadOwner is destroyed, the Triead gets marked as dead
// and gets cleared and disconnected from the App (but not disposed of until
// the reference count goes to 0).
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

	// Get the App where this thread belongs.
	App *app() const
	{
		return app_.get();
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
		app_->markTrieadConstructed(this);
	}

	// Mark that the thread has completed all its connections and
	// is ready to run. This also implies Constructed, and can be
	// used to set both flags at once.
	void markReady()
	{
		app_->markTrieadReady(this);
	}

	// Mark the thread as ready, and wait for all the threads in
	// the app to become ready.
	void readyReady()
	{
		markReady();
		app_->waitReady();
	}

	// Abort the thread and with it the whole app.
	// Typically used if a fatal error is found during initialization.
	// XXX reconcile with markDead()
	// @param msg - message that can communicate the reason fo abort
	void abort(const string &msg) const
	{
		app_->abortBy(triead_->getName(), msg);
	}

	// Mark the thread as dead and free its resources.
	// It's automatically called as a part of TrieadOwner destructor,
	// so normally there should be no need to call it manually.
	// Unless you have some other weird references to TrieadOwner
	// and really want to mark the death right now.
	//
	// This also deletes the references to the units, including the
	// main unit.
	//
	// And it triggers the thread join by the harvester, so the
	// OS-level theread should exit soon.
	void markDead();

	// Find a thread by name.
	// Will wait if the thread has not completed its construction yet.
	// If the thread refers to itself (i.e. the name is of the same thread
	// owner), returns the thread back even if it's not fully constructed yet.
	//
	// Throws an Exception if no such thread is declared nor made,
	// or the thread is declared but not constructed within the App timeout.
	//
	// @param tname - name of the thread to find
	Onceref<Triead> findTriead(const string &tname)
	{
		return app_->findTriead(this, tname);
	}

	// Export a nexus in this thread.
	// Throws an Exception on any errors (such as the thread not belonging to this
	// app, nexus being already exported or having been incorrectly defined).
	//
	// @param nexus - nexus to be exported
	void exportNexus(Nexus *nexus);

	// Find a nexus in a thread by name.
	// Will wait if the thread has not completed its construction yet.
	// If the thread refers to itself (i.e. the name is of the same thread
	// owner), returns the nexus even if the thread not fully constructed yet
	// or fails immediately if the nexus has not been defined yet.
	//
	// Throws an Exception if no such nexus exists within the App timeout.
	//
	// @param tname - name of the target thread that owns the nexus
	// @paran nexname - name of the nexus in it
	// @return - the nexus reference.
	Onceref<Nexus> findNexus(const string &tname, const string &nexname);

protected:
	// Called through App::makeTriead().
	// Creates the thread's "main" same-named unit.
	// @param app - app where this thread belongs
	// @param th - thread, whose control API to represent.
	TrieadOwner(App *app, Triead *th);

protected:
	Autoref<App> app_; // app where the thread belongs
	Autoref<Triead> triead_; // the thread owned here
	Autoref<Unit> mainUnit_; // the main unit, created with the thread
	UnitList units_; // units of this thread, including the main one

private:
	TrieadOwner();
	TrieadOwner(const TrieadOwner &);
	void operator=(const TrieadOwner &);
};

}; // TRICEPS_NS

#endif // __Triceps_TrieadOwner_h__
