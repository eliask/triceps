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
#include <list>
#include <pw/ptwrap.h>
#include <common/Common.h>
#include <app/Triead.h>
#include <app/TrieadJoin.h>

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
	// of apps. This set the deadline with default timeout (which can
	// be changed later, before the creation of the first thread).
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

	// List all the defined Apps, for introspection.
	// @param - a map where all the defined Apps will be returned.
	//     It will be cleared before placing any data into it.
	typedef map<string, Autoref<App> > Map;
	static void getList(Map &ret);

	// Dereference the app from the list. The object will
	// still exist until all the links to it are gone.
	// If the App is already dereferenced, does nothing.
	// @param app - the App to drop
	static void drop(Onceref<App> app);

	// } static interface

public:
	typedef map<string, Autoref<Triead> > TrieadMap;

	// XXX have separate timeouts for Constructed and Ready
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

	// Set an explicit timeout (counting from now) for the initialization
	// deadline.
	// Throws an Exception if any thread exists in the App.
	// @param sec - timeout in seconds
	void setTimeout(int sec);

	// Set an explicit absolute initialization deadline.
	// Throws an Exception if any thread exists in the App.
	// @param dl - deadline, absolute value
	void setDeadline(const timespec &dl);

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

	// Define a join object for the thread. Called by the parent thread.
	// May be left undefined if the thread is detached (not the best idea but doable). 
	// The normal sequence would be:
	// * declare a thread from its parent
	// * start the thread and get its identity
	// * construct a joiner object with this identity and define it
	// The threda identity is not known until it's constructed, so it has to be
	// done after the thread runs but the thread has to be declared before it
	// starts because (1) otherwise the child thread might not define itsels yet
	// and defineJoin() would fail and (2) because some other threads may be
	// waiting for everything being ready, so the parent thread must declare the
	// child threads before it reports itself ready.
	//
	// Will throw an Exception if no such thread is declared nor defined.
	//
	// Theoretically, this method can be called multiple times for the same
	// thread to change or remove (with NULL argument) the joiner but
	// practically it's probably not a good idea.
	//
	// @param tname - name of the thread to define a joiner for; the thread must
	//        be already declared or defined
	// @param j - the joiner, the App will keep a reference to it until the join is done
	void defineJoin(const string &tname, Onceref<TrieadJoin> j);
	
	// Get all the threads defined and declared in the app.
	// The declared but undefined threads will have the value of NULL.
	// @param ret - map where to put the return values (it will be cleared first).
	void getTrieads(TrieadMap &ret) const;

	// Mark the app as aborted. This is done when a thread detects a fatal
	// error after which it could not continue the initialization. The App
	// normally can not continue without any of its threads, so it's better to
	// abort right away than to wait for the thread timeout to expire.
	// The abort immediately makes the App ready, wakes up all the waits
	// for threads, and immediately throws Exception on all the future waits. 
	// But it takes all the threads to be collected as usual for the App to
	// become dead.
	//
	// @param tname - name of the failed thread that calls the abort
	// @param msg - the abort message, allowing to propagate the error info
	void abortBy(const string &tname, const string &msg);

	// Check whether the app was marked as aborted.
	bool isAborted() const;

	// Get the name of the thread that caused the app abort
	// (will be empty if not aborted).
	// The result is NOT a reference but a copy of the string!
	string getAbortedBy() const;
	// Get the message from the aborted thread.
	// The result is NOT a reference but a copy of the string!
	string getAbortedMsg() const;

	// Check whether the app is dead (naturally or aborted).
	// (This check may be called with mutex_ not held or held).
	bool isDead();

	// Wait for the App to become dead.
	void waitDead();

	// The harvester API.
	// The harvester would normally run in a "master" thread. It would
	// join the threads as they die, and after all of them are dead,
	// drop the App.
	// There is expected to be only on eharvester thread, or many
	// assumptions will break.
	// {

	// Do one run of the harvester. Join all the threads that have
	// died since the last run. Resets the "need harvest" flag, unless
	// the whole App is dead.
	// @return - whether the App is dead. Combining the check into this
	//           method allows to avoid a race that would leave the
	//           last thread(s) unharvested.
	bool harvestOnce();

	// Wait for either more threads become harvestable of for the
	// app to become dead.
	// (This check may be called with mutex_ not held or held).
	void waitNeedHarvest();

	// Run the harvester thread logic, harvesting the threads
	// as they die, and after the whole App is dead, drop it.
	// Note that the caller is expected to keep a reference to the App,
	// so teh dead App won't be actually destroyed until that reference
	// is destroyed.
	void harvester();

	// }

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
	// @param immed - flag: find immediate, which means that the thread will be
	//        returned even if it's not constructed yet and there will never be
	//        a wait, so if the thread is declared but not defined yet, an Exception
	//        will be thrown
	// @return - the thread reference.
	Onceref<Triead> findTriead(TrieadOwner *to, const string &tname, bool immed = false);

	// Find a nexus in a thread by name.
	// Will wait if the thread has not completed its construction yet.
	//
	// Throws an Exception if no such nexus exists.
	//
	// @param to - identity of the calling thread (used for the deadlock detection).
	// @param tname - name of the target thread
	// @paran nexname - name of the nexus in it
	// @param immed - flag: find immediate, which means that the thread will be
	//        returned even if it's not constructed yet and there will never be
	//        a wait, so if the thread is declared but not defined yet, an Exception
	//        will be thrown; it also means that it might be looking for nexus
	//        in an incomplete thread, and the nexus must be defined by then
	// @return - the nexus reference.
	Onceref<Nexus> findNexus(TrieadOwner *to, const string &tname, const string &nexname,
		bool immed = false);

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

	// Mark that the thread has exited.
	// This also implies Constructed and Ready, even though it should
	// not normally be used to mark all the flags at once.
	// This also triggers the thread's join by the harvester, 
	// so it should exit soon.
	//
	// @param to - identity of the thread to be marked
	void markTrieadDead(TrieadOwner *to);

	// Check whether the app is ready.
	// (This check may be called with mutex_ not held or held).
	bool isReady();

	// Wait for all the threads to become ready.
	// XXX should it be accessible outside of TrieadOwner?
	void waitReady();

protected:
	// Use App::Make to create new objects.
	// @param name - name of the app.
	App(const string &name);

	// Check whether the app was marked as aborted.
	// Relies on mutex_ being already locked.
	bool isAbortedL() const
	{
		return !abortedBy_.empty();
	}

	// Check that the app is not aborted. Otherwise throws an Exception.
	// Relies on mutex_ being already locked.
	void assertNotAbortedL() const;

	// Check that the thread belongs to this app.
	// If not, throws an Exception.
	// Relies on mutex_ being already locked.
	void assertTrieadL(Triead *th) const;
	void assertTrieadOwnerL(TrieadOwner *to) const;

	// The internal versions. Require the mutex_ to be held
	// by the caller, and also assume that the Triead has been
	// already checked.
	void markTrieadConstructedL(Triead *t);
	void markTrieadReadyL(Triead *t);
	void markTrieadDeadL(Triead *t);

	// Create a timestamp for the initialization deadline.
	// Must be called only before creation of any threads, so since
	// it's all single-threaded, there is no need for locking.
	// @param sec - timeout in seconds from now
	void computeDeadline(int sec);

protected:
	// Since there might be a need to wait for the initialization of
	// even the declared and not yet defined threads, the wait structures
	// exist separately.
	class TrieadUpd : public Mtarget
	{
	public:
		// The mutex would be normally the App object's mutex.
		TrieadUpd(pw::pmutex &mutex):
			waitFor_(NULL),
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

		// For testing: returns the current count of sleepers.
		// This allows the busy-wait until the sleepers get into position.
		// The mutex should be already locked.
		int _countSleepersL();

		Autoref<Triead> t_; // the thread object, will be NULL if only declared
		Autoref<TrieadJoin> j_; // the joiner object, may be NULL for detached or already joined threads

		TrieadUpd *waitFor_; // what thread is this one waiting for (or NULL), for deadlock detection
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
	typedef list<Autoref<TrieadUpd> > TrieadUpdList;

	// The single process-wide directory of all the apps, protected by a mutex.
	static Map apps_;
	static pw::pmutex apps_mutex_;

	mutable pw::pmutex mutex_; // mutex synchronizing this App
	string name_; // name of the App
	string abortedBy_; // name of the thread that aborted the app (empty if not aborted)
	string abortedMsg_; // an optional message from the aborted thread
	TrieadUpdMap threads_; // threads defined and declared
	TrieadUpdList zombies_; // the thread that have exited and need harvesting
	pw::event ready_; // will be set when all the threads are ready
	pw::event dead_; // will be set when all the threads are dead
	pw::event needHarvest_; // will be set when there are zombies to harvest
	timespec deadline_; // deadline for the initialization, set on or soon after App creation
	int unreadyCnt_; // count of threads that aren't ready yet
	int aliveCnt_; // count of threads that aren't dead yet


private:
	App();
	App(const App &);
	void operator=(const App &);
};

}; // TRICEPS_NS

#endif // __Triceps_App_h__
