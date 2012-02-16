//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The encapsulation of Perl compare function for the sorted index.

// Include TricepsPerl.h and PerlCallback.h before this one.

// ###################################################################################

#ifndef __TricepsPerl_PerlSortCondition_h__
#define __TricepsPerl_PerlSortCondition_h__

#include <type/SortedIndexType.h>

using namespace Triceps;

namespace Triceps
{
namespace TricepsPerl 
{

class PerlSortCondition : public SortedIndexCondition
{
public:
	// cbInit and/or cbCompare may be NULL
	PerlSortCondition(Onceref<PerlCallback> cbInit, Onceref<PerlCallback> cbCompare);
	// always makes an uninitialized copy!
	PerlSortCondition(const PerlSortCondition &other);
	~PerlSortCondition();

	// base class methods
	virtual bool equals(const SortedIndexCondition *sc) const;
	virtual bool match(const SortedIndexCondition *sc) const;
	virtual void printTo(string &res, const string &indent = "", const string &subindent = "  ") const;
	virtual SortedIndexCondition *copy() const;
	virtual bool operator() (const RowHandle *r1, const RowHandle *r2) const;
	virtual void initialize(Erref &errors, TableType *tabtype, SortedIndexType *indtype);

	// Set the comparator, could be called from the initializer.
	// It is technically possible to have the initialization called
	// from multiple threads, but don't do that!
	// @return - true on success, false if the object is already initialized
	bool setComparator(Onceref<PerlCallback> cbComparator);

protected:
	// Initialization: may be used to dynamically generate a comparator.
	// The args are: indexType (self), rowType.
	// On success returns undef, on failure an error message.
	Autoref<PerlCallback> cbInitialize_; 

	// Comparison called from operator().
	// The args are: rh1, rh2, rowType.
	// The Perl callback returns the result of (rh1 <=> rh2).
	Autoref<PerlCallback> cbCompare_; 

	bool initialized_; // flag: this object has been initialized
	SV *svRowType_; // avoid creating the row type object on each comparison, cache it
	TableType *tabType_; // remembered for error messages, NOT a reference!
};

}; // Triceps::TricepsPerl
}; // Triceps

using namespace Triceps::TricepsPerl;

#endif // __TricepsPerl_PerlSortCondition_h__
