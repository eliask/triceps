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
#include <type/HoldRowTypes.h>

namespace TRICEPS_NS {

Nexus::Nexus(const string &tname, Facet *facet):
	tname_(tname),
	name_(facet->getShortName()),
	reverse_(facet->isReverse()),
	unicast_(facet->isUnicast())
{ 
	// deep-copy the types
	Autoref<HoldRowTypes> holder = new HoldRowTypes;
	type_ = facet->getFnReturn()->getType()->deepCopy(holder);
	for (RowTypeMap::iterator it = facet->rowTypes_.begin(); it != facet->rowTypes_.end(); ++it)
		rowTypes_[it->first] = holder->copy(it->second);
	for (TableTypeMap::iterator it = facet->tableTypes_.begin(); it != facet->tableTypes_.end(); ++it)
		tableTypes_[it->first] = it->second->deepCopy(holder);
}

}; // TRICEPS_NS
