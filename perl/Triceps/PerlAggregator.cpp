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
	dSP;

	const PerlAggregatorType *at = static_cast<const PerlAggregatorType *>(gadget->getType());

	WrapTable *wtab = new WrapTable(table);
	SV *svtab = newSV(0);
	sv_setref_pv(svtab, "Triceps::Table", (void *)wtab);

	SV *svgadget = newSV(0); // XXX add the gadget

	SV *svindex = newSV(0); // XXX add the index

	WrapIndexType *wpit = new WrapIndexType(const_cast<IndexType *>(parentIndexType));
	SV *svpit = newSV(0);
	sv_setref_pv(svpit, "Triceps::IndexType", (void *)wpit);

	SV *svgh = newSV(0); // XXX add the group handle

	WrapTray *wdest = new WrapTray(table->getUnit(), dest);
	SV *svdest = newSV(0);
	sv_setref_pv(svdest, "Triceps::Tray", (void *)wdest);

	SV *svaggop = newSViv(aggop);

	SV *svopcode = newSViv(opcode);

	WrapRowHandle *wrh = new WrapRowHandle(table, rh);
	SV *svrh = newSV(0);
	sv_setref_pv(svrh, "Triceps::RowHandle", (void *)wrh);

	WrapTray *wcopy = new WrapTray(table->getUnit(), copyTray);
	SV *svcopy = newSV(0);
	sv_setref_pv(svcopy, "Triceps::Tray", (void *)wcopy);

	PerlCallbackStartCall(at->cbHandler_);

	XPUSHs(svtab);
	XPUSHs(svgadget);
	XPUSHs(svindex);
	XPUSHs(svpit);
	XPUSHs(svgh);
	XPUSHs(svdest);
	XPUSHs(svaggop);
	XPUSHs(svopcode);
	XPUSHs(svrh);
	XPUSHs(svcopy);

	PerlCallbackDoCall(at->cbHandler_);
	
	// this calls the DELETE methods on wrappers
	SvREFCNT_dec(svtab);
	SvREFCNT_dec(svgadget);
	SvREFCNT_dec(svindex);
	SvREFCNT_dec(svpit);
	SvREFCNT_dec(svgh);
	SvREFCNT_dec(svdest);
	SvREFCNT_dec(svaggop);
	SvREFCNT_dec(svopcode);
	SvREFCNT_dec(svrh);
	SvREFCNT_dec(svcopy);

	if (SvTRUE(ERRSV)) {
		// If in eval, croak may cause issues by doing longjmp(), so better just warn.
		// Would exit(1) be better?
		warn("Error in unit %s aggregator %s handler: %s", 
			gadget->getUnit()->getName().c_str(), gadget->getName().c_str(), SvPV_nolen(ERRSV));

	}
}

// ########################## wraps ##################################################

WrapMagic magicWrapAggregatorType = { "AggType" };

}; // Triceps::TricepsPerl
}; // Triceps

