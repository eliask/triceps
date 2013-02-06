//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A Triceps Thread.  It keeps together the Nexuses defined by the thread and
// is also used to track the state of the app initialization.

#include <app/Triead.h>

namespace TRICEPS_NS {

Triead::Triead(const string &name) :
	name_(name),
	constructed_(false),
	ready_(false),
	dead_(false)
{ }

void Triead::clear()
{
	// XXX TODO
	// Must make sure that anyone waiting on the construction and
	// readiness gets returned a proper error and doesn't crash!
}

Triead::~Triead()
{
	clear();
}

void Triead::exportNexus(const string &appName, Nexus *nexus)
{
	pw::lockmutex lm(mutex_);

	nexus->setTrieadName(name_); // marks the nexus as exported
	if (exports_.find(nexus->getName()) != exports_.end())
		// the message is intentionally different than in TrieadOwned::exportNexus
		throw Exception::fTrace("Can not export the second nexus with the same name '%s' in thread '%s/%s'.",
			nexus->getName().c_str(), appName.c_str(), name_.c_str());
	exports_[nexus->getName()] = nexus;
}

void Triead::getList(NexusMap &ret) const
{
	pw::lockmutex lm(mutex_);

	if (!ret.empty())
		ret.clear();

	// copy a snapshot of the exports map to the return value
	for (NexusMap::const_iterator it = exports_.begin(); it != exports_.end(); ++it)
		ret.insert(*it);
}

Onceref<Nexus> Triead::findNexus(const string &srcName, const string &appName, const string &name) const
{
	pw::lockmutex lm(mutex_);

	NexusMap::const_iterator it = exports_.find(name);
	if (it == exports_.end())
		throw Exception::fTrace("For thread '%s', the nexus '%s' is not found in application '%s' thread '%s'.", 
			srcName.c_str(), name.c_str(), appName.c_str(), name_.c_str());

	return it->second;
}

}; // TRICEPS_NS
