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
	Autoref<App>
	Autoref<Triead> triead_;
	Autoref<Unit> mainUnit_; // the main unit, created with the thread
	UnitList units_; // units of this thread, includiong the main one

private:
	TrieadOwner();
	TrieadOwner(const TrieadOwner &);
	void operator=(const TrieadOwner &);
};

}; // TRICEPS_NS

#endif // __Triceps_TrieadOwner_h__
