//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A facet represents a nexus imported into a thread.

#ifndef __Triceps_Facet_h__
#define __Triceps_Facet_h__

#include <common/Common.h>
#include <app/Nexus.h>

namespace TRICEPS_NS {

class Facet: public Mtarget
{
public:
	typedef Nexus::RowTypeMap RowTypeMap;
	typedef Nexus::TableTypeMap TableTypeMap;

protected:
	Autoref<Nexus> nexus_; // nexus represented by this facet
	bool writer_; // Flag: this thread is writing into the nexus

	// The elements of the Nexus are copied here. This gives each
	// thread a private copy of the types, and this makes the reference
	// counting in it efficient, keeping the updates inside each CPU's cache.
	Autoref<RowSetType> type_; // the type of the nexus's main queue
	RowTypeMap rowTypes_; // the collection of row types
	TableTypeMap tableTypes_; // the collection of table types

private:
	Facet();
	Facet(const Facet &);
	void operator=(const Facet &);
};

}; // TRICEPS_NS

#endif // __Triceps_Facet_h__
