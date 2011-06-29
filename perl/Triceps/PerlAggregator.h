//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The Triceps aggregator for Perl calls and the wrapper for it.

// Include the Perl headers in TricepsPerl.h before this one.

#include <type/AggregatorType.h>
#include <sched/AggregatorGadget.h>
#include <table/Aggregator.h>

// ###################################################################################

#ifndef __Triceps_PerlAggregator_h__
#define __Triceps_PerlAggregator_h__

using namespace Triceps;

namespace Triceps
{
namespace TricepsPerl 
{

class PerlAggregatorType : public AggregatorType
{
public:
	
	// @param name - name for aggregators' gadget in the table, will be tablename.name
	// @param rt - type of rows produced by this aggregator, will be referenced
	// @param cb - callback, will be referenced
	PerlAggregatorType(const string &name, const RowType *rt, Onceref<PerlCallback> cb);

	// from AggregatorType
	virtual AggregatorType *copy() const;
	// creates just the generic AggregatorGadget, nothing special
	virtual AggregatorGadget *makeGadget(Table *table, IndexType *intype) const;
	virtual Aggregator *makeAggregator(Table *table, AggregatorGadget *gadget) const;

protected:
	friend class PerlAggregator;

	Autoref<PerlCallback> cb_;
};

class PerlAggregator : public Aggregator
{
public:
	// @param table - passed to Aggregator
	// @param gadget - passed to Aggregator
	PerlAggregator(Table *table, AggregatorGadget *gadget);
	virtual ~PerlAggregator();

	// from Aggregator
    virtual void handle(Table *table, AggregatorGadget *gadget, Index *index,
		const IndexType *parentIndexType, GroupHandle *gh, Tray *dest,
		AggOp aggop, Rowop::Opcode opcode, RowHandle *rh, Tray *copyTray);

	// XXX add some way to initialize sv_;
protected:
	SV *sv_; // maye be used to keep the arbitrary Perl values
};

extern WrapMagic magicWrapPerlAggregatorType;
typedef Wrap<magicWrapPerlAggregatorType, PerlAggregatorType> WrapPerlAggregatorType;

extern WrapMagic magicWrapPerlAggregator;
typedef Wrap<magicWrapPerlAggregator, PerlAggregator> WrapPerlAggregator;

}; // Triceps::TricepsPerl
}; // Triceps

using namespace Triceps::TricepsPerl;

#endif // __Triceps_PerlAggregator_h__
