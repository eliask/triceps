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

#include <map>
#include <pw/ptwrap2.h>
#include <common/Common.h>
#include <sched/Unit.h>
#include <app/Nexus.h>
#include <app/Facet.h>

namespace TRICEPS_NS {

// Even though the class name is funny, it's still pronounced as "thread". :-)
// (I want to avoid the name conflicts with the word "thread" that is used all
// over the place). 
class Triead : public Mtarget
{
	friend class TrieadOwner;
	friend class App;
public:
	typedef map<string, Autoref<Nexus> > NexusMap;
	typedef map<string, Autoref<Facet> > FacetMap;

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
	bool isConstructed() const
	{
		return constructed_;
	}

	// Check if all the connections have been completed and the
	// thread is ready to run.
	// Not const since the value might change between the calls,
	// if marked by the owner of this thread.
	bool isReady() const
	{
		return ready_;
	}

	// Check if the thread has already exited. The dead thread
	// is also always marked as completed and ready. It could happen
	// that some threads are still waiting for readiness of the app while the
	// other threads have already found the readiness, executed and exited.
	// Though it should not happen much in the normal operation.
	bool isDead() const
	{
		return dead_;
	}

	// List all the defined Nexuses, for introspection.
	// @param - a map where all the defined Nexuses will be returned.
	//     It will be cleared before placing any data into it.
	void exports(NexusMap &ret) const;

	// List all the imported Nexuses, for introspection.
	// @param - a map where all the imported Facets will be returned.
	//     It will be cleared before placing any data into it.
	void imports(NexusMap &ret) const;

#if 0 // {
	// Get the count of exports.
	int exportsCount() const;
#endif // }

	// Find a nexus with the given name.
	// Throws an Error if not found.
	// @param srcName - name of the Triead that initiated the request
	// @param appName - name of the App where this thread belongs, for error messages
	// @param name - name of the nexus to find
	Onceref<Nexus> findNexus(const string &srcName, const string &appName, const string &name) const;

protected:
	// Called through App::makeThriead().
	// @param name - Name of this thread (within the App).
	Triead(const string &name);

	// Clear all the direct or indirect references to the other threads.
	// Called by the App at the destruction time.
	void clear();
	
	// The TrieadOwner API.
	// Naturally, it can be called from only one thread, the owner one.
	// These calls usually also involve the inter-thread signaling
	// done by the ThreadOwner through App.
	// {

	// Mark that the thread has constructed and exported all of its
	// nexuses.
	void markConstructed()
	{
		constructed_ = true;
	}

	// Mark that the thread has completed all its connections and
	// is ready to run. This also implies Constructed, and can be
	// used to set both flags at once.
	void markReady()
	{
		constructed_ = true;
		ready_ = true;
	}

	// Mark the thread that is has completed the execution and exited.
	void markDead()
	{
		constructed_ = true;
		ready_ = true;
		dead_ = true;
	}

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
	
	// List all the imported Facets, for introspection.
	// @param - a map where all the imported Facets will be returned.
	//     It will be cleared before placing any data into it.
	void facets(FacetMap &ret) const;

	// Export a nexus. Called from TrieadOwner. The nexus must be already
	// marked as exported.
	// Throws an Exception if the name is duplicate or if the thread is already
	// marked as constructed.
	// @param appName - App name, for error messages
	// @param nexus - the nexus to export (TriedOwner keeps a reference to it
	//        during the call)
	void exportNexus(const string &appName, Nexus *nexus);

	// Add the facet to the list of imports.
	// @param facet - facet to import
	void importFacet(Onceref<Facet> facet);

	// Access from TrieadOwner. 
	// The "L" means in this case that the owner thread doesn't even
	// need to lock th emutex.
	FacetMap::const_iterator importsFindL(const string &name) const
	{
		return imports_.find(name);
	}
	FacetMap::const_iterator importsEndL() const
	{
		return imports_.end();
	}
	
	string name_; // name of the thread, read-only
	mutable pw::pmutex mutex_; // mutex synchronizing this Triead
	NexusMap exports_; // the nexuses exported from this thread
	Autoref<QueEvent> qev_;

	// The imports are modified only by the TrieadOwner, so the
	// owner thread may read it without locking. However any
	// modifications and reading by anyone else have to be
	// synchronized by the mutex.
	FacetMap imports_; // the imported facets

	// The flags are interacting with the App's state and
	// are synchronized by the App's mutex.
	// {
	// Flag: all the nexuses of this thread have been defined.
	// When this flag is set, the nexuses become visible.
	bool constructed_;
	// Flag: the thread has been fully initialized, including
	// waiting on readiness of the other threads.
	bool ready_;
	// Flag: the thread has completed execution and exited.
	bool dead_;
	// }

private:
	Triead();
	Triead(const Triead &);
	void operator=(const Triead &);
};
}; // TRICEPS_NS

#endif // __Triceps_Triead_h__
