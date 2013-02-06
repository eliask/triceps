//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Nexus is a communication point between the threads, a set of labels
// for passing data downstream and upstream.

#include <app/Nexus.h>
#include <app/Facet.h>

namespace TRICEPS_NS {

Nexus::Nexus(const string &tname, Facet *facet):
	tname_(tname),
	name_(facet->getFnReturn()->getName()),
	reverse_(facet->reverse_),
	unicast_(facet->unicast_)
{ 
	// deep-copy the types
	// XXX there is a problem with deep-copying: if multiple entries have shared
	// a row type, deep-copying will create separate row types for them
	type_ = facet->getFnReturn()->getType()->deepCopy();
	for (RowTypeMap::iterator it = facet->rowTypes_.begin(); it != facet->rowTypes_.end(); ++it)
		rowTypes_[it->first] = it->second->copy();
	for (TableTypeMap::iterator it = facet->tableTypes_.begin(); it != facet->tableTypes_.end(); ++it)
		tableTypes_[it->first] = it->second; // XXX ->deepCopy();
}

}; // TRICEPS_NS
