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
#include <sched/FnReturn.h>

namespace TRICEPS_NS {

// There are two ways to get a Facet:
// 1. Create it from the bits and pieces and then create and export
//    a nexus from it. The original facet becomes the representation
//    of that nexus in the owner thread (unless you opt out and then
//    that facet just gets discarded).
// 2. Import a nexus and receive a facet as its representation.
//
// A Facet is seen in only one thread, so it's an Starget.
class Facet: public Starget
{
public:
	typedef Nexus::RowTypeMap RowTypeMap;
	typedef Nexus::TableTypeMap TableTypeMap;

	// Create the Facet from the minimal set of fragments.
	// The extra row types and table types can be added later in
	// the chained fashion. Any errors found in the construction
	// will be saved and can be read later, or will cause an Exception
	// to be thrown at export time.
	//
	// @param fret - the FnReturn that will determine the type of the nexus'es
	//        queue. The FnReturn's name is used for the Facet's and Nexus'es
	//        name. The FnReturn may be not initialized yet, it will be then
	//        initialized.
	// @param writer - flag: the owner thread will be writing into this facet,
	//        otherwise reading from it; if it will be doing neither then
	//        you can use either value
	Facet(Onceref<FnReturn> fret, bool writer);

	// The convenience methods that make remembering the options
	// easier.
	static Facet *makeReader(Onceref<FnReturn> fret)
	{
		return new Facet(fret, false);
	}
	static Facet *makeWriter(Onceref<FnReturn> fret)
	{
		return new Facet(fret, true);
	}

	// Export a row type through the nexus. It won't be a part of the
	// queue, just a row type that can be imported by the other threads.
	// May be called only until the Facet is exported or will throw an Exception.
	//
	// If the Facet is imported, this will throw an Exception.
	//
	// @param name - name of the row type, these are in a separate namespace from
	//         the types in the FnReturn
	// @param rtype - row type to export
	// @return - the same Facet
	Facet *exportRowType(const string &name, Onceref<RowType> rtype);

	// Export a table type through the nexus. It can be imported
	// by the other threads.
	// May be called only until the Facet is exported or will throw an Exception.
	//
	// If the Facet is imported, this will throw an Exception.
	//
	// @param name - name of the table type, these are in a separate namespace from
	//         the row types
	// @param tt - table type to export
	// @return - the same Facet
	Facet *exportTableType(const string &name, Onceref<TableType> tt);

	// Check whether this facet is imported (and that means, also exported).
	// As opposed to being in the middle of creation.
	// An imported facet is final. A non-imported facet can be constructed
	// further and eventually exported.
	bool isImported() const
	{
		return !nexus_.isNull();
	}

protected:
	// XXX add a constructor for import from a Nexus

	// Check that the Facet is not ex/imported, or throw an Exception.
	void assertNotImported();

	string name_; // the name is set only in the ex/imported facet:
		// it includes two parts separated by a "/": the nexus owner thread
		// name and the nexus name.
	Autoref<Nexus> nexus_; // nexus represented by this facet
	bool writer_; // Flag: this thread is writing into the nexus;
		// ignored in the non-imported facets

	Erref err_; // the collected errors

	// The elements that are either used to construct a nexus or are
	// deep-copied from a nexus. This gives each thread a private
	// set of types, making the reference-counting efficient.
	Autoref<FnReturn> fret_; // the interface to the nexus'es queue
	RowTypeMap rowTypes_; // the collection of row types
	TableTypeMap tableTypes_; // the collection of table types

private:
	Facet();
	Facet(const Facet &);
	void operator=(const Facet &);
};

}; // TRICEPS_NS

#endif // __Triceps_Facet_h__
