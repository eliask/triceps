//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// Helper functions for Perl wrapper.

#include <string.h>
#include <wrap/Wrap.h>
#include <common/Strprintf.h>
#include <mem/EasyBuffer.h>

// ###################################################################################

using namespace Triceps;

namespace Triceps
{
namespace TricepsPerl 
{

// Clear the perl $! variable
void clearErrMsg();

// Set a message in Perl $! variable
// @param msg - error message
void setErrMsg(const std::string &msg);

// Copy a Perl scalar (numeric) SV value into a memory buffer.
// @param ti - field type selection
// @param val - SV to copy from
// @param bytes - memory buffer to copy to, must be large enough
// @return - true if set OK, false if value was non-numeric
bool svToBytes(Type::TypeId ti, SV *val, char *bytes);

// Convert a Perl value (scalar or list) to a buffer
// with raw bytes suitable for setting into a record.
// Does NOT check for undef, the caller must do that before.
// Also silently allows to set the arrays for the scalar fields
// and scalars into arrays.
// 
// @param ti - field type selection
// @param arg - value to post to, must be already checked for SvOK
// @param fname - field name, for error messages
// @return - new buffer (with size_ set), or NULL (then with error set)
EasyBuffer * valToBuf(Type::TypeId ti, SV *arg, const char *fname);

// Convert a byte buffer from a row to a Perl value.
// @param ti - id of the simple type
// @param arsz - array size, affects the resulting value:
//        Type::AR_SCALAR - returns a scalar
//        anything else - returns an array reference
//        (except that TT_STRING and TT_UINT8 are always returned as Perl scalar strings)
// @param notNull - if false, returns an undef (suiitable for putting in an array)
// @param data - the raw data buffer
// @param dlen - data buffer length
// @param fname - field name, for error messages
// @return - a new SV
SV *bytesToVal(Type::TypeId ti, int arsz, bool notNull, const char *data, intptr_t dlen, const char *fname);

// Parse an option value of reference to array into a NameSet
// On error calls setErrMsg and returns NULL.
// @param funcName - calling function name, for error messages
// @param optname - option name of the originating value, for error messages
// @param ref - option value (will be checked for being a reference to array)
// @return - the parsed NameSet or NULL on error
Onceref<NameSet> parseNameSet(const char *funcName, const char *optname, SV *optval);

// Parse an enqueuing mode as an integer or string constant to an enum.
// On error calls setErrMsg and returns false.
// @param funcName - calling function name, for error messages
// @param enqMode - SV containing the value to parse
// @param em - place to return the parsed value
// @return - true on success or false on error
bool parseEnqMode(const char *funcName, SV *enqMode, Gadget::EnqMode &em);

// Parse an opcode as an integer or string constant to an enum.
// On error calls setErrMsg and returns false.
// @param funcName - calling function name, for error messages
// @param opcode - SV containing the value to parse
// @param op - place to return the parsed value
// @return - true on success or false on error
bool parseOpcode(const char *funcName, SV *opcode, Rowop::Opcode &op);

// Parse an IndexId as an integer or string constant to an enum.
// On error calls setErrMsg and returns false.
// @param funcName - calling function name, for error messages
// @param idarg - SV containing the value to parse
// @param id - place to return the parsed value
// @return - true on success or false on error
bool parseIndexId(const char *funcName, SV *idarg, IndexType::IndexId &id);

// Enqueue one argument in a unit. The argument may be either a Rowop or a Tray,
// detected automatically. Checks for errors and populates the error messages.
// @param funcName - calling function name, for error messages
// @param u - unit where to enqueue
// @param em - enqueuing mode
// @param arg - argument (should be Rowop or Tray reference)
// @param i - argument number, for error messages
// @return - true on success, false on error
bool enqueueSv(char *funcName, Unit *u, Gadget::EnqMode em, SV *arg, int i);

// The Unit::Tracer subclasses hierarchy is partially exposed to Perl. So an Unit::Tracer
// object can not be returned to Perl by a simple wrapping and blessing to a fixed class.
// Instead its recognised subclasses must be blessed to the correct Perl classes.
// This function returns the correct perl class for blessing.
// @param tr - tracer object (must not be NULL!!!)
// @return - perl class name, in a static string (which must be never modified!)
char *translateUnitTracerSubclass(const Unit::Tracer *tr);

// An encapsulation of a Perl callback: used to remember a reference
// to Perl code and to the optional arguments to it.
// Since Perl uses macros for the function call sequences,
// this encapsulation also gets used from macros.
//
// A catch is that the code args (ir even the code, as a closure)
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

public:
	// for macros, the internals must be public
	SV *code_; // the code reference
	vector<SV *> args_; // optional arguments for the code

private:
	PerlCallback(const PerlCallback &);
	void operator=(const PerlCallback &);
};

// Initialize the PerlCallback object. On failure sets code_ to NULL and sets the error message.
// @param cb - callback object poniter
// @param fname - function name, for error messages
// @param first - index of the first argument, that must represent a code reference
// @param count - count of arguments, if less than 1 then considered an error
#define PerlCallbackInitialize(cb, fname, first, count) \
	do { \
		int _i = first, _c = count; \
		if (_c < 1) { \
			cb->clear(); \
			setErrMsg( string(fname) + ": missing Perl callback function reference argument" ); \
			break; \
		} \
		if (!cb->setCode(ST(_i), fname)) \
			break; \
		while (--_c > 0) /* pre-ops to skip the code */ \
			cb->appendArg(ST(++_i)); \
	} while(0)

// The normal call is done as follows:
//   if (cb) {
//       PerlCallbackStartCall(cb);
//       ... push fixed arguments ...
//       PerlCallbackDoCall(cb);
//       if (SvTRUE(ERRSV)) {
//           ... print a warning ...
//       }
//   }

// Start the call sequence.
// @param cb - callback object poniter
#define PerlCallbackStartCall(cb) \
	do { \
		ENTER; SAVETMPS; \
		PUSHMARK(SP); \
	} while(0)

// Complete the call sequence
// @param cb - callback object poniter
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

// Label that executes Perl code
class PerlLabel : public Label
{
public:
	
	// @param unit - the unit where this label belongs
	// @param rtype - type of row to be handled by this label
	// @param name - a human-readable name of this label, for tracing
	// @param cb - callback object
	PerlLabel(Unit *unit, const_Onceref<RowType> rtype, const string &name, Onceref<PerlCallback> cb);
	~PerlLabel();

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
	void clear()
	{
		cb_ = NULL;
	}

protected:
	// from Label
	virtual void execute(Rowop *arg) const;

	Autoref<PerlCallback> cb_;
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

// A common macro to print the contents of assorted objects.
// See RowType.xs for an example of usage
#define GEN_PRINT_METHOD(subtype)  \
		static char funcName[] =  "Triceps::" #subtype "::print"; \
		clearErrMsg(); \
		subtype *rt = self->get(); \
		\
		if (items > 3) { \
			setErrMsg( strprintf("Usage: %s(RowType [, indent  [, subindent ] ])", funcName)); \
			XSRETURN_UNDEF; \
		} \
		\
		string indent, subindent; \
		const string *indarg = &indent; \
		\
		if (items > 1) { /* parse indent */ \
			if (SvOK(ST(1))) { \
				const char *p; \
				STRLEN len; \
				p = SvPV(ST(1), len); \
				indent.assign(p, len); \
			} else { \
				indarg = &NOINDENT; \
			} \
		} \
		if (items > 2) { /* parse subindent */ \
			const char *p; \
			STRLEN len; \
			p = SvPV(ST(2), len); \
			subindent.assign(p, len); \
		} else { \
			subindent.assign("  "); \
		} \
		\
		string res; \
		rt->printTo(res, *indarg, subindent); \
		XPUSHs(sv_2mortal(newSVpvn(res.c_str(), res.size())));

}; // Triceps::TricepsPerl
}; // Triceps

using namespace Triceps::TricepsPerl;

