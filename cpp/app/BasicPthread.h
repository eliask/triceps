//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A basic OS-level Posix thread implementation for Triceps.

#ifndef __Triceps_BasicPthread_h__
#define __Triceps_BasicPthread_h__

#include <app/App.h>
#include <app/TrieadOwner.h>

namespace TRICEPS_NS {

// This implements the TrieadJoiner API around the Pthreads.
// It also does the typical framework for statekeeping.
// Derive your subclass from this class, and define the
// method execute().
class BasicPthread : public TrieadJoin
{
public:
	// The constructor with the minimal arguments.
	// Most of the work is done in the start() because it needs to
	// be able to throw the exceptions safely.
	//
	// @param name - name of the thread, will be passed to App::makeTriead().
	BasicPthread(const string &name);

	// Start the thread's execution. Before starting,
	// it defines the thread in the app and creates the TrieadOwner
	// (could declare it first and define sfter start but since C++
	// allows the passing of objects into the threads, this way is easier).
	// Which allows to report the start failures even before the OS
	// thread is created.
	//
	// After start, automatically calls defineJoin() in the app.
	// If it fails, will abort the App and throws the Exception.
	//
	// Propagates the Exception from nested calls.
	//
	// @param app - App where the thread gets created.
	void start(Autoref<App> app);

	// Define this one for the code of your thread.
	// By this time the Triead will be created and registered
	// with the app. After exit, the thread will be automatically
	// marked as dead.
	//
	// If after exit the thread is not marked as ready, it will
	// abort the App.
	//
	// If the method thows a Triceps::Exception, it will be
	// caught and converted to the App abort.
	//
	// @param to - the pre-created owner object for this thread.
	//        No need to create a reference here, since the caller
	//        will already keep a reference.
	virtual void execute(TrieadOwner *to) = 0;

	// from TrieadJoin
	virtual void join();

protected:
	// The function that will be passed to Posix.
	static void *run_it(void *arg);

	// Arguments passed to the thread. Add more in your
	// subclass as needed.
	string name_; // name of the app

	// Mutex used to synchronize the start of the thread.
	pw::pmutex startMutex_;
	// The temporary self-reference used to pass this object to the thread.
	// Will be reset once the thread starts and creates its stack-based
	// reference. This makes sure that this object won't get destroyed
	// while it's used by anyone.
	Autoref<BasicPthread> selfref_;
	// The TrieadOwner also exists only until the thread actually starts
	// (or fails to start). Then it becomes moved to a local variable. 
	// This works OK at avoiding the ref cycles in two ways:
	// 1. Until the thread is started, this object won't be placed into
	// the App's defineJoin().
	// 2. After the thread is started, the self-reference will be set to NULL,
	// and the reference will be kept on the stack, then destroyed when the
	// thread exits.
	Autoref<TrieadOwner> to_;
	// the Posix thread id, for join
	pthread_t id_; // the thread itself must not use it because of the population race

private:
	BasicPthread();
	BasicPthread(const BasicPthread &);
	void operator=(const BasicPthread &);
};

}; // TRICEPS_NS

#endif // __Triceps_BasicPthread_h__
