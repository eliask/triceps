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
#include <app/Facet.h>

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
	typedef Triead::NexusMap NexusMap;
	typedef Triead::FacetMap FacetMap;

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
	//
	// The last thread marked ready triggers the check of the
	// App topology that may throw an Exception.
	void markReady()
	{
		app_->markTrieadReady(this);
	}

	// Mark the thread as ready, and wait for all the threads in
	// the app to become ready.
	//
	// The last thread marked ready triggers the check of the
	// App topology that may throw an Exception.
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
	// If the thread was not ready before, it will be marked
	// ready now, and if it was the last one to become ready,
	// that will trigger the loop check in the App. However
	// if a loop is found and an Exception is thrown, it will
	// be caught and ignored. However the App will still be
	// marked aborted.
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
	// @param immed - flag: find immediate, which means that the thread will be
	//        returned even if it's not constructed yet and there will never be
	//        a wait, so if the thread is declared but not defined yet, an Exception
	//        will be thrown
	Onceref<Triead> findTriead(const string &tname, bool immed = false)
	{
		return app_->findTriead(this, tname, immed);
	}

	// Export a nexus in this thread.
	// Throws an Exception on any errors are found (such as errors in the
	// facet or a duplicate name).
	//
	// @param facet - Facet used to create the Nexus. Its name will also
	//        determine the Nexus'es name in the thread.
	// @param import - flag: import the nexus right back through the
	//        same facet and make it available to the constructing thread.
	//        If false, the facet will be left un-imported, and can be
	//        discarded.
	// @return - the same facet, for a convenient chaining of the calls, like:
	//        Autoref<Facet> myfacet = to->exportNexus(
	//            Facet::makeWriter(FnReturn::make("My")->...)
	//            ->setReverse()
	//            ->exportTableType(Table::make(...)->...)
	//        );
	Onceref<Facet> exportNexus(Autoref<Facet> facet, bool import = true);
	// A syntactic sugar: export with no automatic re-import.
	Onceref<Facet> exportNexusNoImport(Autoref<Facet> facet)
	{
		return exportNexus(facet, false);
	}

	// Import a nexus from a thread by name, producing its local facet.
	//
	// The facet will have its FnReturn created in the thread's main unit.
	//
	// If this nexus has been already imported, will return the previously
	// imported copy. The as-name and the direction (read or write) must match
	// or an Exception will not be throw. You may not import the same nexus
	// for both reading and writing into the same thread.
	//
	// Normally will wait if the thread has not completed its construction yet.
	// The target thread must be at least declared, or the import will fail right away.
	//
	// But if the immediate flag is set, the wait for construction is skipped
	// and the nexus is looked up in the thread immediately. If the thread or
	// nexus in it has not been defined yet, the immediate import will fail.
	// If the thread refers to itself (i.e. the name is of the same thread
	// as this thread owner), it always works as immediate.
	//
	// Throws an Exception if no such nexus exists within the App timeout.
	//
	// @param tname - name of the target thread that owns the nexus
	// @param nexname - name of the nexus in it
	// @param asname - name of the facet to be created from this nexus, very
	//        much like the SQL "AS clause", which allows to avoid both the
	//        local duplicates and the long full names. If empty, will
	//        be set to the same as the nexus name.
	// @param writer - flag: this thread will be writing into the nexus,
	//        otherwise reading from it
	// @param immed - flag: the nexus lookup is immediate, not waiting for its
	//        thread to be fully constructed
	// @return - the imported facet reference.
	Onceref<Facet> importNexus(const string &tname, const string &nexname, const string &asname, 
		bool writer, bool immed = false);
	// Syntactic sugar varieties.
	Onceref<Facet> importNexusImmed(const string &tname, const string &nexname, const string &asname,
		bool writer)
	{
		return importNexus(tname, nexname, asname, writer, true);
	}
	Onceref<Facet> importReader(const string &tname, const string &nexname, const string &asname = "",
		bool immed=false)
	{
		return importNexus(tname, nexname, asname, false, immed);
	}
	Onceref<Facet> importWriter(const string &tname, const string &nexname, const string &asname = "",
		bool immed=false)
	{
		return importNexus(tname, nexname, asname, true, immed);
	}
	Onceref<Facet> importReaderImmed(const string &tname, const string &nexname, const string &asname = "")
	{
		return importNexus(tname, nexname, asname, false, true);
	}
	Onceref<Facet> importWriterImmed(const string &tname, const string &nexname, const string &asname = "")
	{
		return importNexus(tname, nexname, asname, true, true);
	}

	// Convenience wrappers that forward to the Triead.
	void exports(NexusMap &ret) const
	{
		return triead_->exports(ret);
	}
	void imports(FacetMap &ret) const
	{
		return triead_->facets(ret);
	}

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
