//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The Triceps aggregator for Perl calls and the wrapper for it.

#include <typeinfo>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "PerlAggregator.h"

// ###################################################################################

using namespace Triceps;

namespace Triceps
{
namespace TricepsPerl 
{

// ####################### PerlAggregatorType ########################################

PerlAggregatorType::PerlAggregatorType(const string &name, const RowType *rt, Onceref<PerlCallback> cb):
	AggregatorType(name, rt),
	cb_(cb)
{ }

AggregatorType *PerlAggregatorType::copy() const
{
	return new PerlAggregatorType(*this);
}

AggregatorGadget *PerlAggregatorType::makeGadget(Table *table, IndexType *intype) const
{
	// just use the generic gadget, there is nothing special about it
	return new AggregatorGadget(this, table, intype);
}

Aggregator *PerlAggregatorType::makeAggregator(Table *table, AggregatorGadget *gadget) const
{
	// XXX call the Perl constructor for the per-aggregator SV
	return new PerlAggregator(table, gadget);
}

// ######################## PerlAggregator ###########################################

PerlAggregator::PerlAggregator(Table *table, AggregatorGadget *gadget):
	sv_(NULL)
{ }

PerlAggregator::~PerlAggregator()
{
	if (sv_ != NULL)
		SvREFCNT_dec(sv_);
}

void PerlAggregator::handle(Table *table, AggregatorGadget *gadget, Index *index,
	const IndexType *parentIndexType, GroupHandle *gh, Tray *dest,
	AggOp aggop, Rowop::Opcode opcode, RowHandle *rh, Tray *copyTray)
{
	// XXX do something
}

// ########################## wraps ##################################################

WrapMagic magicWrapPerlAggregatorType = { "PAggTyp" };
WrapMagic magicWrapPerlAggregator = { "PAggreg" };

}; // Triceps::TricepsPerl
}; // Triceps

