//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A basic OS-level Posix thread implementation for Triceps.

#include <string.h>
#include <app/BasicPthread.h>

namespace TRICEPS_NS {

BasicPthread::BasicPthread(const string &name):
	name_(name),
	id_(0)
{ }

void BasicPthread::start(Autoref<App> app)
{
	to_ = app->makeTriead(name_); // might throw
	selfref_ = this; // will be reset to NULL in run_it
	int err = pthread_create(&id_, NULL, run_it, (void *)this); // sets id_
	if (err != 0) {
		selfref_ = NULL;
		string s = strprintf("failed to start: err=%d %s",
			err, strerror(err));
		to_->abort(s);
		to_ = NULL;
		throw Exception::fTrace("In Triceps app '%s' failed to start thread '%s': err=%d %s",
			app->getName().c_str(), name_.c_str(), err, strerror(err));
	}
	app->defineJoin(name_, this);
}

void BasicPthread::join()
{
	if (id_ != 0) {
		pthread_join(id_, NULL);
		id_ = 0;
	}
}

void *BasicPthread::run_it(void *arg)
{
	// Keep the self-reference for the duration of the run
	Autoref<BasicPthread> self = (BasicPthread *)arg;
	self->selfref_ = NULL;
	Autoref<TrieadOwner> to = self->to_;
	self->to_ = NULL;

	try {
		self->execute(to);
	} catch (Exception e) {
		to->abort(e.getErrors()->print());
	}

	if (!to->get()->isReady()) {
		to->abort("thread execution completed without marking it as ready");
	}

	to->markDead();
	return NULL;
}

}; // TRICEPS_NS
