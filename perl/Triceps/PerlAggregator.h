//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The Triceps aggregator for Perl calls and the wrapper for it.

// Include TricepsPerl.h and PerlCallback.h before this one.

#include <common/Conf.h>
#include <type/AggregatorType.h>
#include <sched/AggregatorGadget.h>
#include <table/Aggregator.h>

// ###################################################################################

#ifndef __TricepsPerl_PerlAggregator_h__
#define __TricepsPerl_PerlAggregator_h__

using namespace TRICEPS_NS;

namespace TRICEPS_NS
{
namespace TricepsPerl 
{

class PerlAggregatorType : public AggregatorType
{
public:
	
	// @param name - name for aggregators' gadget in the table, will be tablename.name
	// @param rt - type of rows produced by this aggregator, will be referenced
	// @param cbConstructor - callback for construction of sv_ in aggregator, may be NULL, 
	//        will be referenced
	// @param cbHandler - callback for execution of aggregator, will be referenced
	PerlAggregatorType(const string &name, const RowType *rt, 
		Onceref<PerlCallback> cbConstructor, Onceref<PerlCallback> cbHandler);

	// from AggregatorType
	virtual AggregatorType *copy() const;
	// creates just the generic AggregatorGadget, nothing special
	virtual AggregatorGadget *makeGadget(Table *table, IndexType *intype) const;
	virtual Aggregator *makeAggregator(Table *table, AggregatorGadget *gadget) const;

	// from Type
	virtual bool equals(const Type *t) const;
	virtual bool match(const Type *t) const;

protected:
	friend class PerlAggregator;

	Autoref<PerlCallback> cbConstructor_; // constructs sv_ for makeAggregator
	Autoref<PerlCallback> cbHandler_; // handler called from PerlAggregator
};

class PerlAggregator : public Aggregator
{
public:
	// @param table - passed to Aggregator
	// @param gadget - passed to Aggregator
	// @param sv - state SV or NULL, increases its refcount if not NULL
	PerlAggregator(Table *table, AggregatorGadget *gadget, SV *sv);
	virtual ~PerlAggregator();

	// from Aggregator
    virtual void handle(Table *table, AggregatorGadget *gadget, Index *index,
		const IndexType *parentIndexType, GroupHandle *gh, Tray *dest,
		AggOp aggop, Rowop::Opcode opcode, RowHandle *rh);

	// Set a new value in sv_, increases the refcount if not NULL.
	void setsv(SV *sv);
protected:
	SV *sv_; // maye be used to keep the arbitrary Perl values
};

extern WrapMagic magicWrapAggregatorType;
typedef Wrap<magicWrapAggregatorType, PerlAggregatorType> WrapAggregatorType;

}; // Triceps::TricepsPerl
}; // Triceps

using namespace TRICEPS_NS::TricepsPerl;

#endif // __TricepsPerl_PerlAggregator_h__
