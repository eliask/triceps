//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// Helpers to call Perl code back from C++.

// Include TricepsPerl.h before this one.

// ###################################################################################

#ifndef __TricepsPerl_PerlCallback_h__
#define __TricepsPerl_PerlCallback_h__

#include <common/Conf.h>

using namespace TRICEPS_NS;

namespace TRICEPS_NS
{
namespace TricepsPerl 
{

// An encapsulation of a Perl callback: used to remember a reference
// to Perl code and to the optional arguments to it.
// Since Perl uses macros for the function call sequences,
// this encapsulation also gets used from macros.
//
// A catch is that the code args (or even the code, as a closure)
// may reference back to the object that holds this callback, thus
// creating a reference loop. To break this loop, the callback needs
// to be explicitly cleared before disposing of its owner object.
class  PerlCallback : public Starget
{
public:
	PerlCallback();
	~PerlCallback(); // clears

	// Clear the contents, decrementing the references to objects.
	void clear();

	// Set code_. Implicitly does clear();
	// @param code - Perl code reference for processing the rows; will check
	//               for correctness; will make a copy of it (because if keeping a reference,
	//               SV may change later, a copy is guaranteed to stay the same).
	// @param fname - caller function name, for error messages
	// @return - true on success, false (and error code) on failure.
	bool setCode(SV *code, const char *fname);

	// Append another argument to args_.
	// @param arg - argument value to append; will make a copy of it.
	void appendArg(SV *arg);

	// Check that the value of the code and args are the same
	bool equals(const PerlCallback *other) const;

public:
	// for macros, the internals must be public
	SV *code_; // the code reference
	vector<SV *> args_; // optional arguments for the code

private:
	PerlCallback(const PerlCallback &);
	void operator=(const PerlCallback &);
};

// equality comparison for two pointers to PerlCallback
bool callbackEquals(const PerlCallback *p1, const PerlCallback *p2);

// Initialize the PerlCallback object. On failure sets code_ to NULL and sets the error message.
// (The code reference is split from the arguments).
// @param cb - callback object poniter
// @param fname - function name, for error messages
// @param code - the code reference
// @param firstarg - index of the first argument for the code
// @param countarg - count of arguments, if less than 0 then considered an error
#define PerlCallbackInitializeSplit(cb, fname, code, firstarg, countarg) \
	do { \
		int _i = firstarg, _c = countarg; \
		if (_c < 0) { \
			cb->clear(); \
			setErrMsg( string(fname) + ": missing Perl callback function reference argument" ); \
			break; \
		} \
		if (!cb->setCode(code, fname)) \
			break; \
		while (_c-- > 0) \
			cb->appendArg(ST(_i++)); \
	} while(0)
// Initialize the PerlCallback object. On failure sets code_ to NULL and sets the error message.
// @param cb - callback object poniter
// @param fname - function name, for error messages
// @param first - index of the first argument, that must represent a code reference
// @param count - count of arguments, if less than 1 then considered an error
#define PerlCallbackInitialize(cb, fname, first, count) PerlCallbackInitializeSplit(cb, fname, ST(first), (first)+1, (count)-1)

// The normal void call is done as follows:
//   if (cb) {
//       PerlCallbackStartCall(cb);
//       ... push fixed arguments ...
//       PerlCallbackDoCall(cb);
//       callbackSuccessOrThrow();
//   }
//
// The normal call that retuns a scalar is done as follows:
//   if (cb) {
//       SV *result = NULL;
//       PerlCallbackStartCall(cb);
//       ... push fixed arguments ...
//       PerlCallbackDoCallScalar(cb, result);
//       callbackSuccessOrThrow();
//       ... process the result ...
//   }
//
//   If don't want to throw, use instead the manual error check:
//       if (SvTRUE(ERRSV)) {
//           ... print a warning ...
//       }

// Start the call sequence.
// @param cb - callback object poniter
#define PerlCallbackStartCall(cb) \
	do { \
		ENTER; SAVETMPS; \
		PUSHMARK(SP); \
	} while(0)

// Complete the call sequence
// @param cb - callback object pointer
#define PerlCallbackDoCall(cb) \
	do { \
		const vector<SV *> &_av = cb->args_; \
		if (!_av.empty()) { \
			for (size_t _i = 0; _i < _av.size(); ++_i) { \
				XPUSHs(_av[_i]); \
			} \
		} \
		PUTBACK;  \
		call_sv(cb->code_, G_VOID|G_EVAL); \
		SPAGAIN; \
		FREETMPS; LEAVE; \
	} while(0)

// Complete the call sequence returning a scalar
// @param cb - callback object pointer
// @param result - result variable (if call returns nothing, may be left unchanged),
//        if a non-NULL value is placed there, its refcounter will be increased
//        before returning
#define PerlCallbackDoCallScalar(cb, result) \
	do { \
		const vector<SV *> &_av = cb->args_; \
		int _nv; \
		if (!_av.empty()) { \
			for (size_t _i = 0; _i < _av.size(); ++_i) { \
				XPUSHs(_av[_i]); \
			} \
		} \
		PUTBACK;  \
		_nv = call_sv(cb->code_, G_SCALAR|G_EVAL); \
		SPAGAIN; \
		if (_nv >= 1) {  \
			for (; _nv > 1; _nv--) \
				POPs; \
			result = POPs; \
			if (result != NULL) \
				SvREFCNT_inc(result); \
		} \
		PUTBACK;  \
		FREETMPS; LEAVE; \
	} while(0)

// Check ERRSV for the callback execution errors.
// If any errors found throws an Exception with the error message
// constructed of the text of ERRSV and the arguments.
// Since the typical situation invilve sthe stack unroll,
// the error is created not nested but first the ERRSV text,
// then at the same level the arguments.
//
// @param fmt, ... - the prefix for the error message
void callbackSuccessOrThrow(const char *fmt, ...)
	__attribute__((format(printf, 1, 2)));

// Label that executes Perl code
class PerlLabel : public Label
{
public:
	
	// @param unit - the unit where this label belongs
	// @param rtype - type of row to be handled by this label
	// @param name - a human-readable name of this label, for tracing
	// @param clr - callback object for clearing (may be NULL)
	// @param cb - callback object for data processing (may be NULL)
	PerlLabel(Unit *unit, const_Onceref<RowType> rtype, const string &name, 
		Onceref<PerlCallback> clr, Onceref<PerlCallback> cb);
	~PerlLabel();

	// Create a simple Perl label with the default clearing callback
	// and the code reference snippet for the body, no arguments.
	// A factory method used in the FnBinding abd such.
	// It could be a common constructor, excapt that it throws an
	// Exception if it finds any error.
	//
	// @param unit - the unit where this label belongs
	// @param rtype - type of row to be handled by this label
	// @param name - a human-readable name of this label, for tracing
	// @param code - a function reference (if not, will throw an error)
	// @param fmt, ... - the prefix for the error message
	// @return - the newly constructed label
	static Onceref<PerlLabel> makeSimple(Unit *unit, const_Onceref<RowType> rtype,
		const string &name, SV *code, const char *fmt, ...)
		__attribute__((format(printf, 5, 6)));

	// Get back the code reference (don't give it directly to random Perl code,
	// make a copy!)
	SV *getCode() const
	{
		if (cb_.isNull())
			return NULL;
		else
			return cb_->code_;
	}

	// Clear the callback
	void clearSubclass();

protected:
	// from Label
	virtual void execute(Rowop *arg) const;

	Autoref<PerlCallback> clear_; // the Perl code for clearing (may be NULL)
	Autoref<PerlCallback> cb_; // the Perl callback for processing data (may be NULL)
};

// A tracer that executes Perl code.
class UnitTracerPerl : public Unit::Tracer
{
public:
	// @param cb - callback object
	UnitTracerPerl(Onceref<PerlCallback> cb);

	// Clear the callback
	void clear()
	{
		cb_ = NULL;
	}

	// from Unit::Tracer
	virtual void execute(Unit *unit, const Label *label, const Label *fromLabel, Rowop *rop, Unit::TracerWhen when);

protected:
	Autoref<PerlCallback> cb_;
};

// Extract a function reference from a Perl SV value.
// Throws a Triceps::Exception if the value is not an array reference.
// (Similar to the others in TricepsPerl.h)
//
// @param svptr - the Perl SV* from which the value will be extracted.
//     It can be in one of 2 formats:
//         * a plain function reference
//         * a reference to an array containing a function reference
//           and the argument values for the call
// @param fmt, ... - the prefix for the error message
// @return - the newly created callback object
Onceref<PerlCallback> GetSvCall(SV *svptr, const char *fmt, ...)
	__attribute__((format(printf, 2, 3)));

}; // Triceps::TricepsPerl
}; // Triceps


#endif // __TricepsPerl_PerlCallback_h__
