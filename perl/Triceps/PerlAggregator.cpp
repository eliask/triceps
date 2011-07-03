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
#include "PerlCallback.h"
#include "PerlAggregator.h"

// ###################################################################################

using namespace Triceps;

namespace Triceps
{
namespace TricepsPerl 
{

// ####################### PerlAggregatorType ########################################

PerlAggregatorType::PerlAggregatorType(const string &name, const RowType *rt, 
		Onceref<PerlCallback> cbConstructor, Onceref<PerlCallback> cbHandler):
	AggregatorType(name, rt),
	cbConstructor_(cbConstructor),
	cbHandler_(cbHandler)
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

bool PerlAggregatorType::equals(const Type *t) const
{
	if (!AggregatorType::equals(t))
		return false;

	const PerlAggregatorType *at = static_cast<const PerlAggregatorType *>(t);

	if (cbConstructor_.isNull() ^ at->cbConstructor_.isNull())
		return false;

	if ( (!cbConstructor_.isNull() && !cbConstructor_->equals(at->cbConstructor_))
	|| !cbHandler_->equals(at->cbHandler_))
		return false;

	return true;
}

bool PerlAggregatorType::match(const Type *t) const
{
	if (!AggregatorType::match(t))
		return false;

	const PerlAggregatorType *at = static_cast<const PerlAggregatorType *>(t);

	if (cbConstructor_.isNull() ^ at->cbConstructor_.isNull())
		return false;

	if ( (!cbConstructor_.isNull() && !cbConstructor_->equals(at->cbConstructor_))
	|| !cbHandler_->equals(at->cbHandler_))
		return false;

	return true;
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

void PerlAggregator::setsv(SV *sv)
{
	if (sv_ != NULL)
		SvREFCNT_dec(sv_);
	sv_= sv;
	SvREFCNT_inc(sv_);
}

void PerlAggregator::handle(Table *table, AggregatorGadget *gadget, Index *index,
	const IndexType *parentIndexType, GroupHandle *gh, Tray *dest,
	AggOp aggop, Rowop::Opcode opcode, RowHandle *rh, Tray *copyTray)
{
	// XXX do something
}

// ########################## wraps ##################################################

WrapMagic magicWrapAggregatorType = { "AggType" };

}; // Triceps::TricepsPerl
}; // Triceps

