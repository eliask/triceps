//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The Application class that manages the threads. There may be multiple
// Apps in one program, each with a different name.

#include <app/App.h>

namespace TRICEPS_NS {

Onceref<App> App::make(const string &name)
{
	pw::lockmutex lm(apps_mutex_);

	Map::iterator it = apps_.find(name);
	if (it != apps_.end())
		throw Exception::fTrace("Duplicate Triceps application name '%s' is not allowed.", name.c_str());

	App *a = new App(name);
	apps_[name] = a;
	return a;
}

Onceref<App> App::find(const string &name)
{
	pw::lockmutex lm(apps_mutex_);

	Map::iterator it = apps_.find(name);
	if (it == apps_.end())
		throw Exception::fTrace("Triceps application '%s' is not found.", name.c_str());

	return it->second;
}

void App::list(Map &ret)
{
	pw::lockmutex lm(apps_mutex_);

	if (!ret.empty())
		ret.clear();

	// copy a snapshot of the apps map to the return value
	for (Map::iterator it = apps_.begin(); it != apps_.end(); ++it)
		ret.insert(*it);
}

App::App(const string &name)
	: name_(name)
{ }

Onceref<TrieadOwner> App::makeTriead(const string &tname)
{
	if (name.empty())
		throw Exception::fTrace("Empty thread name is not allowed, in application '%s'.", name_.c_str());

	TrieadMap::iterator it = threads_.find(tname);
	if (it != threads_.end())
		throw Exception::fTrace("Duplicate thread name '%s' is not allowed, in application '%s'.", 
			tname.c_str(), name_.c_str());

	Triead *th = new Triead(name);
	TrieadOwner *ow = new TrieadOwner(th);
	threads_[tname] = th;

	return ow; // the only owner API for the thread!
}

}; // TRICEPS_NS

