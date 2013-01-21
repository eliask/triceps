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
	timeout_(DEFAULT_TIMEOUT),
	unreadyCnt_(0),
	ready_(true) // since no threads are unready
{ }

Onceref<TrieadOwner> App::makeTriead(const string &tname)
{
	if (tname.empty())
		throw Exception::fTrace("Empty thread name is not allowed, in application '%s'.", name_.c_str());

	pw::lockmutex lm(mutex_);

	TrieadUpdMap::iterator it = threads_.find(tname);
	TrieadUpd *upd;
	if (it == threads_.end()) {
		upd = new TrieadUpd(mutex_);
		threads_[tname] = upd;
		if (++unreadyCnt_ == 1)
			ready_.reset();
	} else {
		upd = it->second;
		if(!upd->t_.isNull())
			throw Exception::fTrace("Duplicate thread name '%s' is not allowed, in application '%s'.", 
				tname.c_str(), name_.c_str());
	}

	Triead *th = new Triead(tname);
	TrieadOwner *ow = new TrieadOwner(this, th);
	upd->t_ = th;

	return ow; // the only owner API for the thread!
}

void App::declareTriead(const string &tname)
{
	if (tname.empty())
		throw Exception::fTrace("Empty thread name is not allowed, in application '%s'.", name_.c_str());

	pw::lockmutex lm(mutex_);
	TrieadUpdMap::iterator it = threads_.find(tname);
	if (it == threads_.end()) {
		threads_[tname] = new TrieadUpd(mutex_);
		if (++unreadyCnt_ == 1)
			ready_.reset();
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
	TrieadUpdMap::const_iterator it = threads_.find(th->getName());
	if (it == threads_.end()) {
		throw Exception::fTrace("Thread '%s' does not belong to the application '%s'.",
			th->getName().c_str(), name_.c_str());
	}
	if (it->second->t_.get() != th) {
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

	// The assertion above makes sure that this succeeds.
	Autoref<TrieadUpd> selfupd = threads_.find(to->get()->getName())->second;
	if (selfupd->waitFor_ != NULL)
		throw Exception::fTrace("In app '%s' thread '%s' object must not be used from 2 OS threads.",
			name_.c_str(), to->get()->getName().c_str());

	TrieadUpdMap::iterator it = threads_.find(tname);
	if (it == threads_.end())
		throw Exception::fTrace("In app '%s' thread '%s' is referring to a non-existing thread '%s'.",
			name_.c_str(), to->get()->getName().c_str(), tname.c_str());

	Autoref <TrieadUpd> upd = it->second;
	Triead *t = upd->t_;
	if (t != NULL && t->isConstructed())
		return t;

	// Make sure that won't deadlock: go through the dependency
	// chain and ensure that it doesn't return back to our thread.
	for (TrieadUpd *p = upd; p != NULL; p = p->waitFor_) {
		if (p == selfupd.get()) {
			// print the list of dependencies, it repeats the same loop
			Erref trace = new Errors(true);
			for (TrieadUpd *pp = upd; pp != selfupd.get(); pp = pp->waitFor_)
				trace->appendMsg(true, pp->t_->getName() + " waits for " + pp->waitFor_->t_->getName());
			Erref err = new Errors(strprintf(
					"In app '%s' thread '%s' waiting for thread '%s' would cause a deadlock:",
						name_.c_str(), to->get()->getName().c_str(), tname.c_str()),
				trace);
			throw new Exception(err, true);
		}
	}

	timespec limit;
	initTimespec(limit);

	selfupd->waitFor_ = upd;
	try {
		do {
			upd->waitL(name_, tname, limit); // will throw on timeout
			t = upd->t_;
		} while (t == NULL || !t->isConstructed());
		selfupd->waitFor_ = NULL;
	} catch (...) {
		selfupd->waitFor_ = NULL;
		throw;
	}

	return t;
}

void App::markTrieadConstructed(TrieadOwner *to)
{
	pw::lockmutex lm(mutex_);

	Triead *t = to->get();
	assertTrieadL(t); // means the the find below can't fail

	if (!t->isConstructed()) {
		t->markConstructed();
		TrieadUpdMap::iterator it = threads_.find(t->getName());
		it->second->broadcastL(name_);
	}
}

void App::markTrieadReady(TrieadOwner *to)
{
	pw::lockmutex lm(mutex_);

	Triead *t = to->get();
	assertTrieadL(t);

	if (!t->isReady()) {
		t->markReady();
		if (--unreadyCnt_ == 0)
			ready_.signal();
	}
}

void App::waitReady()
{
	timespec limit;
	initTimespec(limit);

	int err = ready_.timedwait(limit);
	if (err != 0) {
		if (err == ETIMEDOUT) {
			Erref lags = new Errors(true);
			{
				pw::lockmutex lm(mutex_); // reading the list must be protected
				for (TrieadUpdMap::iterator it = threads_.begin(); it != threads_.end(); ++it) {
					Triead *t = it->second->t_;
					if (t == NULL) {
						lags->appendMsg(true, it->first + ": not defined");
					} else if (!t->isConstructed()) {
						lags->appendMsg(true, it->first + ": not constructed");
					} else if (!t->isReady()) {
						lags->appendMsg(true, it->first + ": not ready");
					}
				}
			}
			Erref err = new Errors(strprintf(
				"Application '%s' did not initialize within the time limit.\nThe lagging threads are:", name_.c_str()),
				lags);
			throw new Exception(err, true);
		} else  {
			throw Exception::fTrace("Internal error: condvar wait for all-ready in application '%s' failed, errno=%d: %s.", 
				name_.c_str(), err, strerror(err));
		}
	}
}

}; // TRICEPS_NS

