//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Nexus is a communication point between the threads, a set of labels
// for passing data downstream and upstream.

#include <app/Nexus.h>

namespace TRICEPS_NS {

Nexus::Nexus(Triead *parent, const string &name) :
	name_(name),
	parent_(parent)
{
}

}; // TRICEPS_NS
