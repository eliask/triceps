//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The Application class that manages the threads. There may be multiple
// Apps in one program, each with a different name.

#include <string.h>
#include <app/App.h>
#include <app/TrieadOwner.h>
#include <app/Nexus.h>

namespace TRICEPS_NS {

// -------------------- App::TrieadUpd -----------------------------------

void App::TrieadUpd::broadcastL(const string &appname)
{
	int err = cond_.broadcast();
	if (err != 0)
		throw Exception::fTrace("Internal error: condvar broadcast failed in application '%s', errno=%d: %s.", 
			appname.c_str(), err, strerror(err));
}

void App::TrieadUpd::waitL(const string &appname, const string &tname, const timespec &abstime)
{
	int err = cond_.timedwait(abstime);
	if (err != 0) {
		if (err == ETIMEDOUT)
			throw Exception::fTrace("Thread '%s' in application '%s' did not initialize within the time limit.", 
				tname.c_str(), appname.c_str());
		else 
			throw Exception::fTrace("Internal error: condvar wait for thread '%s' in application '%s' failed, errno=%d: %s.", 
				tname.c_str(), appname.c_str(), err, strerror(err));
	}
}

// -------------------- App ----------------------------------------------

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

App::App(const string &name) :
	name_(name),
	timeout_(DEFAULT_TIMEOUT)
{ }

Onceref<TrieadOwner> App::makeTriead(const string &tname)
{
	if (tname.empty())
		throw Exception::fTrace("Empty thread name is not allowed, in application '%s'.", name_.c_str());

	pw::lockmutex lm(mutex_);

	TrieadMap::iterator it = threads_.find(tname);
	if (it != threads_.end())
		throw Exception::fTrace("Duplicate thread name '%s' is not allowed, in application '%s'.", 
			tname.c_str(), name_.c_str());

	Triead *th = new Triead(tname);
	TrieadOwner *ow = new TrieadOwner(this, th);
	threads_[tname] = th;

	TrieadUpdMap::iterator upit = upd_.find(tname);
	if (upit == upd_.end()) {
		upd_[tname] = new TrieadUpd(mutex_);
	} else {
		// Already declared and there might be someone waiting for definition.
		upit->second->broadcastL(name_);
	}

	return ow; // the only owner API for the thread!
}

void App::declareTriead(const string &tname)
{
	if (tname.empty())
		throw Exception::fTrace("Empty thread name is not allowed, in application '%s'.", name_.c_str());

	pw::lockmutex lm(mutex_);
	TrieadUpdMap::iterator upit = upd_.find(tname);
	if (upit == upd_.end()) {
		upd_[tname] = new TrieadUpd(mutex_);
	} // else just do nothing
}

void App::exportNexus(TrieadOwner *to, Nexus *nexus)
{
	pw::lockmutex lm(mutex_);

	assertTrieadOwnerL(to);
	if (nexus->isInitialized())
		throw Exception::fTrace("Nexus '%s' is already exported, can not export again in app '%s' thread '%s'.",
			nexus->getName().c_str(), name_.c_str(), to->get()->getName().c_str());

	// XXX TODO
	// Add to the thread.
	// Find if anyone is waiting for this nexus, and wake them up.
}

void App::assertTrieadL(Triead *th) const
{
	TrieadMap::const_iterator it = threads_.find(th->getName());
	if (it == threads_.end()) {
		throw Exception::fTrace("Thread '%s' does not belong to the application '%s'.",
			th->getName().c_str(), name_.c_str());
	}
	if (it->second.get() != th) {
		throw Exception::fTrace("Thread '%s' does not belong to the application '%s', it's same-names but from another app.",
			th->getName().c_str(), name_.c_str());
	}
}

void App::assertTrieadOwnerL(TrieadOwner *to) const
{
	assertTrieadL(to->get());
}

void App::initTimespec(timespec &ret) const
{
	clock_gettime(CLOCK_REALTIME, &ret); // the current time
	ret.tv_sec += timeout_;
}

Onceref<Triead> App::findTriead(TrieadOwner *to, const string &tname)
{
	pw::lockmutex lm(mutex_);

	assertTrieadOwnerL(to);

	// A special short-circuit for the self-reference, a thread can
	// find itself even if it's not fully constructed.
	if (to->get()->getName() == tname)
		return to->get();

	TrieadMap::iterator it = threads_.find(tname);
	if (it != threads_.end() && it->second->isConstructed())
		return it->second;

	TrieadUpdMap::iterator upit = upd_.find(tname);
	if (upit == upd_.end())
		throw Exception::fTrace("In app '%s' thread '%s' is referring to a non-existing thread '%s'.",
			name_.c_str(), to->get()->getName().c_str(), tname.c_str());

	timespec limit;
	initTimespec(limit);

	do {
		upit->second->waitL(name_, tname, limit); // will throw on timeout
		it = threads_.find(tname);
	} while (it == threads_.end() || !it->second->isConstructed());

	return it->second;
}

}; // TRICEPS_NS

