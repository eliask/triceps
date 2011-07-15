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
#include "WrapAggregatorContext.h"

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
	dSP;

	const PerlAggregatorType *at = static_cast<const PerlAggregatorType *>(gadget->getType());

	WrapTable *wtab = new WrapTable(table);
	SV *svtab = newSV(0);
	sv_setref_pv(svtab, "Triceps::Table", (void *)wtab);

	WrapAggregatorContext *ctx = new WrapAggregatorContext(table, gadget, index, parentIndexType, gh, dest, copyTray);
	SV *svctx = newSV(0); 
	sv_setref_pv(svctx, "Triceps::AggregatorContext", (void *)ctx); // takes over the reference
	// warn("DEBUG PerlAggregator::handle context %p created with refcnt %d ptr %d", ctx, SvREFCNT(svctx), SvROK(svctx));
	SV *svctxcopy = newSV(0); // makes sure that the context stays referenced even if Perl code thanges its SV
	sv_setsv(svctxcopy, svctx);

	SV *svaggop = newSViv(aggop);

	SV *svopcode = newSViv(opcode);

	WrapRowHandle *wrh = new WrapRowHandle(table, rh);
	SV *svrh = newSV(0);
	sv_setref_pv(svrh, "Triceps::RowHandle", (void *)wrh);

	PerlCallbackStartCall(at->cbHandler_);

	XPUSHs(svtab);
	XPUSHs(svctx);
	XPUSHs(svaggop);
	XPUSHs(svopcode);
	XPUSHs(svrh);

	PerlCallbackDoCall(at->cbHandler_);
	
	// warn("DEBUG PerlAggregator::handle invalidating context");
	ctx->invalidate(); // context will stop working, even if Perl code kept a reference

	// this calls the DELETE methods on wrappers
	SvREFCNT_dec(svtab);
	// warn("DEBUG PerlAggregator::handle context decrease refcnt %d ptr %d", SvREFCNT(svctx), SvROK(svctx));
	SvREFCNT_dec(svctx);
	// warn("DEBUG PerlAggregator::handle context copy decrease refcnt %d ptr %d", SvREFCNT(svctxcopy), SvROK(svctxcopy));
	SvREFCNT_dec(svctxcopy);
	SvREFCNT_dec(svaggop);
	SvREFCNT_dec(svopcode);
	SvREFCNT_dec(svrh);

	if (SvTRUE(ERRSV)) {
		// If in eval, croak may cause issues by doing longjmp(), so better just warn.
		// Would exit(1) be better?
		warn("Error in unit %s aggregator %s handler: %s", 
			gadget->getUnit()->getName().c_str(), gadget->getName().c_str(), SvPV_nolen(ERRSV));

	}
	// warn("DEBUG PerlAggregator::handle done");
}

// ########################## wraps ##################################################

WrapMagic magicWrapAggregatorType = { "AggType" };

}; // Triceps::TricepsPerl
}; // Triceps

