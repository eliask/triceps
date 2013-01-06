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
#include <pw/ptwrap.h>
#include <common/Common.h>
#include <app/Triead.h>

namespace TRICEPS_NS {

class Triead; // The Triceps Thread
class TrieadOwner; // The Triceps Thread's Owner interface
class Nexus;

class App : public Mtarget
{
protected:

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

	// Get the name
	const string &getName() const
	{
		return name_;
	}

	// Create a new thread.
	//
	// Throws an Exception if the name is empty or not unique.
	//
	// @param name - name of the thread to create. Must be unique in the App.
	Onceref<TrieadOwner> makeTriead(const string &tname);

	// Export a nexus in a thread.
	// Throws an Exception on any errors (such as the thread not belonging to this
	// app, nexus being already exported or having been incorrectly defined).
	//
	// @param to - thread that owns the nexus
	// @param nexus - nexus to be exported
	void exportNexus(TrieadOwner *to, Nexus *nexus);

protected:
	// Use App::Make to create new objects.
	// @param name - name of the app.
	App(const string &name);

	// Check that the thread belongs to this app.
	// If not, throws an Exception.
	// Relies on mutex_ being already locked.
	void assertTrieadL(Triead *th);
	void assertTrieadOwnerL(TrieadOwner *to);

protected:
	// The single process-wide directory of all the apps, protected by a mutex.
	static Map apps_;
	static pw::pmutex apps_mutex_;

	static pw::pmutex mutex_; // mutex synchronizing this App
	string name_; // name of the App
	TrieadMap threads_; // threads defined in this App

private:
	App();
	App(const App &);
	void operator=(const App &);
};

}; // TRICEPS_NS

#endif // __Triceps_App_h__
