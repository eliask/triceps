//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// Helpers to call Perl code back from C++.

#include <typeinfo>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "PerlCallback.h"

// ###################################################################################

using namespace Triceps;

namespace Triceps
{
namespace TricepsPerl 
{

///////////////////////// PerlCallback ///////////////////////////////////////////////

PerlCallback::PerlCallback() :
	code_(NULL)
{ }

PerlCallback::~PerlCallback()
{
	clear();
}

void PerlCallback::clear()
{
	if (code_) {
		SvREFCNT_dec(code_);
		code_ = NULL;
	}
	if (!args_.empty()) {
		for (size_t i = 0; i < args_.size(); i++) {
			SvREFCNT_dec(args_[i]);
		}
		args_.clear();
	}
}

bool PerlCallback::setCode(SV *code, const char *fname)
{
	clear();

	if (!SvROK(code) || SvTYPE(SvRV(code)) != SVt_PVCV) {
		setErrMsg( string(fname) + ": code must be a reference to Perl function" );
		return false;
	}

	code_ = newSV(0);
	sv_setsv(code_, code);
	return true;
}

// Append another argument to args_.
// @param arg - argument value to append; will make a copy of it.
void PerlCallback::appendArg(SV *arg)
{
	SV *argcp = newSV(0);
	sv_setsv(argcp, arg);
	args_.push_back(argcp);
}

///////////////////////// PerlLabel ///////////////////////////////////////////////

PerlLabel::PerlLabel(Unit *unit, const_Onceref<RowType> rtype, const string &name, Onceref<PerlCallback> cb) :
	Label(unit, rtype, name),
	cb_(cb)
{ }

PerlLabel::~PerlLabel()
{ }

void PerlLabel::execute(Rowop *arg) const
{
	dSP;

	if (cb_.isNull()) {
		warn("Error in unit %s label %s handler: attempted to call the label that has been cleared", 
			getUnit()->getName().c_str(), getName().c_str());
		return;
	}

	WrapRowop *wrop = new WrapRowop(arg);
	SV *svrop = newSV(0);
	sv_setref_pv(svrop, "Triceps::Rowop", (void *)wrop);

	WrapLabel *wlab = new WrapLabel(const_cast<PerlLabel *>(this));
	SV *svlab = newSV(0);
	sv_setref_pv(svlab, "Triceps::Label", (void *)wlab);

	PerlCallbackStartCall(cb_);

	XPUSHs(svlab);
	XPUSHs(svrop);

	PerlCallbackDoCall(cb_);

	// this calls the DELETE methods on wrappers
	SvREFCNT_dec(svrop);
	SvREFCNT_dec(svlab);

	if (SvTRUE(ERRSV)) {
		// If in eval, croak may cause issues by doing longjmp(), so better just warn.
		// Would exit(1) be better?
		warn("Error in unit %s label %s handler: %s", 
			getUnit()->getName().c_str(), getName().c_str(), SvPV_nolen(ERRSV));

	}
}

///////////////////////// UnitTracerPerl ///////////////////////////////////////////////

UnitTracerPerl::UnitTracerPerl(Onceref<PerlCallback> cb) :
	cb_(cb)
{ }

void UnitTracerPerl::execute(Unit *unit, const Label *label, const Label *fromLabel, Rowop *rop, Unit::TracerWhen when)
{
	dSP;

	if (cb_.isNull()) {
		warn("Error in unit %s tracer: attempted to call the tracer that has been cleared", 
			unit->getName().c_str());
		return;
	}

	SV *svunit = newSV(0);
	sv_setref_pv(svunit, "Triceps::Unit", (void *)(new WrapUnit(unit)));

	SV *svlab = newSV(0);
	sv_setref_pv(svlab, "Triceps::Label", (void *)(new WrapLabel(const_cast<Label *>(label))));

	SV *svfrlab = newSV(0);
	if (fromLabel != NULL)
		sv_setref_pv(svfrlab, "Triceps::Label", (void *)(new WrapLabel(const_cast<Label *>(fromLabel))));

	SV *svrop = newSV(0);
	sv_setref_pv(svrop, "Triceps::Rowop", (void *)(new WrapRowop(rop)));

	SV *svwhen = newSViv(when);

	PerlCallbackStartCall(cb_);

	XPUSHs(svunit);
	XPUSHs(svlab);
	XPUSHs(svfrlab);
	XPUSHs(svrop);
	XPUSHs(svwhen);

	PerlCallbackDoCall(cb_);

	// this calls the DELETE methods on wrappers
	SvREFCNT_dec(svunit);
	SvREFCNT_dec(svlab);
	SvREFCNT_dec(svfrlab);
	SvREFCNT_dec(svrop);
	SvREFCNT_dec(svwhen);

	if (SvTRUE(ERRSV)) {
		// If in eval, croak may cause issues by doing longjmp(), so better just warn.
		// Would exit(1) be better?
		warn("Error in unit %s tracer: %s", 
			unit->getName().c_str(), SvPV_nolen(ERRSV));

	}
}

}; // Triceps::TricepsPerl
}; // Triceps


