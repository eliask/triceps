//
// (C) Copyright 2011-2012 Sergey A. Babkin.
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

using namespace TRICEPS_NS;

namespace TRICEPS_NS
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

bool PerlCallback::equals(const PerlCallback *other) const
{
	if (args_.size() != other->args_.size())
		return false;
	if ((code_ == NULL) ^ (other->code_ == NULL))
		return false;

	if (code_ != NULL && SvIV(code_) != SvIV(other->code_)) // same reference
		return false;

	dSP;

	for (size_t i = 0; i < args_.size(); ++i) {
		int nv;
		int result;
		bool error = false;
		SV *a1 = args_[i];
		SV *a2 = other->args_[i];

		ENTER; SAVETMPS; 

		PUSHMARK(SP);
		XPUSHs(a1);
		XPUSHs(a2);
		PUTBACK; 

		const char *func = ((SvIOK(a1) || SvNOK(a1)) && (SvIOK(a2) || SvNOK(a2))) ? "Triceps::_compareNumber" :  "Triceps::_compareText" ;
		nv = call_pv(func, G_SCALAR|G_EVAL);

		if (SvTRUE(ERRSV)) {
			warn("Internal error in function %s: %s", func, SvPV_nolen(ERRSV));
			error = true;
		}

		SPAGAIN;
		if (nv < 1) { 
			result = 1; // doesn't match
		} else {
			for (; nv > 1; nv--)
				POPs;
			SV *perlres = POPs;
			result = SvTRUE(perlres);
		}
		PUTBACK; 

		FREETMPS; LEAVE;

		if (error || result) // if equal, the comparison will be 0
			return false;
	}
	
	return true;
}

bool callbackEquals(const PerlCallback *p1, const PerlCallback *p2)
{
	if (p1 == NULL || p2 == NULL) {
		return p1 == p2;
	} else {
		return p1->equals(p2);
	}
}

///////////////////////// PerlLabel ///////////////////////////////////////////////

PerlLabel::PerlLabel(Unit *unit, const_Onceref<RowType> rtype, const string &name, 
		Onceref<PerlCallback> clr, Onceref<PerlCallback> cb) :
	Label(unit, rtype, name),
	clear_(clr),
	cb_(cb)
{ }

PerlLabel::~PerlLabel()
{ }

void PerlLabel::execute(Rowop *arg) const
{
	dSP;

	if (cb_.isNull()) {
		warn("Error in label %s handler: attempted to call the label that has been cleared", getName().c_str());
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
		clearErrMsg(); // in case if it was thrown by Triceps, clean up
		// propagate to the caller
		Erref err = new Errors(SvPV_nolen(ERRSV));
		err->appendMsg(true, strprintf("Detected in the unit '%s' label '%s' execution handler.", getUnitName().c_str(), getName().c_str()));
		throw TRICEPS_NS::Exception(err, false);
	}
}

void PerlLabel::clearSubclass()
{
	dSP;

	cb_ = NULL; // drop the execution callback

	if (clear_.isNull()) 
		return; // nothing to do
	
	WrapLabel *wlab = new WrapLabel(const_cast<PerlLabel *>(this));
	SV *svlab = newSV(0);
	sv_setref_pv(svlab, "Triceps::Label", (void *)wlab);

	PerlCallbackStartCall(clear_);

	XPUSHs(svlab);

	PerlCallbackDoCall(clear_);

	// this calls the DELETE methods on wrappers
	SvREFCNT_dec(svlab);

	clear_ = NULL; // eventually drop the callback, before any chance of throwing!

	if (SvTRUE(ERRSV)) {
		clearErrMsg(); // in case if it was thrown by Triceps, clean up
		// propagate to the caller
		Erref err = new Errors(SvPV_nolen(ERRSV));
		err->appendMsg(true, strprintf("Detected in the unit '%s' label '%s' clearing handler.", getUnitName().c_str(), getName().c_str()));
		throw TRICEPS_NS::Exception(err, false);
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


