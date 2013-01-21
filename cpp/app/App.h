//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The Application class that manages the threads. There may be multiple
// Apps in one program, each with a different name.

#ifndef __Triceps_App_h__
#define __Triceps_App_h__

#include <map>
#include <set>
#include <pw/ptwrap.h>
#include <common/Common.h>
#include <app/Triead.h>

namespace TRICEPS_NS {

class Triead; // The Triceps Thread
class TrieadOwner; // The Triceps Thread's Owner interface
class Nexus;

class App : public Mtarget
{
	friend class TrieadOwner;

public:
	// the static interface {

	// Create an app with a given name and remember it in the directory
	// of apps. 
	// 
	// Throws an Exception if the App with this name already exists.
	//
	// @param name - name of the app to create, must be unique.
	// @return - reference to the newly created application, in case if
	//     it's about to be used, so that there is no need to immediately
	//     look it up.
	static Onceref<App> make(const string &name);

	// Find a named App.
	//
	// Throws an Exception if the app is not found.
	//
	// @param name - name of the app to find, it must already be created.
	// @return - reference to the app.
	static Onceref<App> find(const string &name);

	// XXX how does an App get deleted?

	// List all the defined Apps, for introspection.
	// @param - a map where all the defined Apps will be returned.
	//     It will be cleared before placing any data into it.
	typedef map<string, Autoref<App> > Map;
	static void list(Map &ret);

	// } static interface

public:
	typedef map<string, Autoref<Triead> > TrieadMap;

	enum {
		// The default timeout (seconds) when waiting for the threads
		// to initialize.
		DEFAULT_TIMEOUT = 30,
	};

	// Get the name
	const string &getName() const
	{
		return name_;
	}

	// Create a new thread.
	//
	// Throws an Exception if the name is empty or not unique.
	//
	// @param tname - name of the thread to create. Must be unique in the App.
	Onceref<TrieadOwner> makeTriead(const string &tname);

	// Declare a thread's name.
	// After that the thread can be found: it will wait for the thread's
	// construction and not throw an error. Not needed if the thread is known
	// to already exist. It's OK to declare a Triead that already exists,
	// then it becomes a no-op.
	//
	// I.e. if a parent C++ thread creates a Triead and then gives its name
	// to a child C++ thread as a source of data, there is no need for declaration
	// because the parent thread is already defined.
	// But if a parent C++ thread creates a child C++ thread, giving it a Triead 
	// name to use, and then wants to connect to that child Triead, it has to
	// declare that Triead first to avoid the race with the child thread not
	// being able to define a Triead before the parent trying to use it.
	// 
	// There are two caveats though:
	// 1. The child thread still might die before it completes the initialization.
	//    For this, there is a timeout.
	// 2. If the parent thread tries to connect to the child AND the child tries
	//    to connect to the parent, avoid the race by fully constructing the
	//    parent Triead and only then starting the child thread. Otherwise a
	//    deadlock is possible. It will be detected reliably, but then still
	//    you would have to fix it like this.
	//
	// @param tname - name of the thread to declare. If already declared, this
	//        method will do nothing.
	void declareTriead(const string &tname);

	// Get all the threads defined and declared in the app.
	// The declared but undefined threads will have the value of NULL.
	// @param ret - map where to put the return values (it will be cleared first).
	void getTrieads(TrieadMap &ret) const;

protected:
	// The TrieadOwner's interface. These user calls are forwarded through TrieadOwner.
	
	// Find a thread by name.
	// Will wait if the thread has not completed its construction yet.
	// If the thread refers to itself (i.e. the name is of the same thread
	// owner, returns the thread back even if it's not fully constructed yet).
	//
	// Throws an Exception if no such thread is declared nor made,
	// or the thread is declared but not constructed within the timeout.
	//
	// @param to - identity of the calling thread (used for the deadlock detection).
	// @param tname - name of the thread
	Onceref<Triead> findTriead(TrieadOwner *to, const string &tname);

	// Export a nexus in a thread.
	// Throws an Exception on any errors (such as the thread not belonging to this
	// app, nexus being already exported or having been incorrectly defined).
	//
	// @param to - thread that owns the nexus
	// @param nexus - nexus to be exported
	void exportNexus(TrieadOwner *to, Nexus *nexus);

	// Find a nexus in a thread by name.
	// Will wait if the thread has not completed its construction yet.
	//
	// Throws an Exception if no such nexus exists.
	//
	// @param to - identity of the calling thread (used for the deadlock detection).
	// @param tname - name of the target thread
	// @paran nexname - name of the nexus in it
	// @return - the nexus reference.
	Onceref<Nexus> findNexus(TrieadOwner *to, const string &tname, const string &nexname);

	// Mark that the thread has constructed and exported all of its
	// nexuses. This wakes up anyone waiting.
	//
	// @param to - identity of the thread to be marked
	void markTrieadConstructed(TrieadOwner *to);

	// Mark that the thread has completed all its connections and
	// is ready to run. This also implies Constructed, and can be
	// used to set both flags at once.
	//
	// @param to - identity of the thread to be marked
	void markTrieadReady(TrieadOwner *to);

	// Wait for all the threads to become ready.
	// XXX should it be accessible outside of TrieadOwner?
	void waitReady();

protected:
	// Use App::Make to create new objects.
	// @param name - name of the app.
	App(const string &name);

	// Check that the thread belongs to this app.
	// If not, throws an Exception.
	// Relies on mutex_ being already locked.
	void assertTrieadL(Triead *th) const;
	void assertTrieadOwnerL(TrieadOwner *to) const;

	// Create a timestamp for the wait time limit, timeout_ from now.
	// @param ret - the struct timespec to fill out
	void initTimespec(timespec &ret) const;

protected:
	// Since there might be a need to wait for the initialization of
	// even the declared and not yet defined threads, the wait structures
	// exist separately.
	class TrieadUpd : public Mtarget
	{
	public:
		// The mutex would be normally the App object's mutex.
		TrieadUpd(pw::pmutex &mutex):
			cond_(mutex)
		{ }

		// Signals the condvar and throws an Exception if it fails
		// (which should never happen but who knows).
		// The mutex should be already locked.
		//
		// @param appname - application name, for error messages
		void broadcastL(const string &appname);

		// Waits for the condition, time-limited to the App's timeout.
		// (To maintain the limit through repeated calls, it's built by
		// the caller and passed as an argument).
		// Throws an Exception if the wait times out or on any
		// other error.
		// The mutex should be already locked.
		//
		// @param appname - application name, for error messages
		// @param tname - thread name of this object, for error messages
		// @param abstime - the time limit
		void waitL(const string &appname, const string &tname, const timespec &abstime);

		Autoref<Triead> t_; // the thread object, will be NULL if only declared

	protected:
		// Condvar for waiting for any updates in the Triead status.
		pw::pchaincond cond_; // all chained from the App's mutex_

		// XXX TODO figure out the destruction sequence
		// Condvar for waiting for any sleepers to wake up and go away.
		// pw::pchaincond freecond_; // all chained from the App's mutex_
	private:
		TrieadUpd();
		TrieadUpd(const TrieadUpd &);
		void operator=(const TrieadUpd &);
	};
	typedef map<string, Autoref<TrieadUpd> > TrieadUpdMap;

	// The single process-wide directory of all the apps, protected by a mutex.
	static Map apps_;
	static pw::pmutex apps_mutex_;

	static pw::pmutex mutex_; // mutex synchronizing this App
	string name_; // name of the App
	TrieadUpdMap threads_; // threads defined and declared
	int timeout_; // timeout in seconds for waiting for initialization // XXX add a method to change it
	int unreadyCnt_; // count of threads that aren't ready yet
	pw::event ready_; // will be set when all the threads are ready

private:
	App();
	App(const App &);
	void operator=(const App &);
};

}; // TRICEPS_NS

#endif // __Triceps_App_h__
