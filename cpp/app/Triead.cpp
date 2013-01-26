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

}; // TRICEPS_NS
