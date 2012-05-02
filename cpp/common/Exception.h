//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Exception to propagate the fatal errors through multiple levels of calling.

#ifndef __Triceps_Exception_h__
#define __Triceps_Exception_h__

#include <exception>
#include <common/Conf.h>
#include <common/Errors.h>

namespace TRICEPS_NS {

using namespace std;

// The exception is used to report the major errors of the fatal
// type. It's kind of like abort() but allows to propagate the stack-trace
// levels from the C++ level to the level of the scripting-language wrapper.
//
// It should be used only sparingly and only when there is no other way
// to report the error, such as in the code that is called through the 
// scheduler.
//
// Make sure to leave everything in a consistent state when throwing the
// exception. After all, it might be caught, and the operation re-issued.
// Especially avoid leaving any memory leaks.

class Exception : public std::exception
{
public:
	// The error message is kept in the structured form.
	// The exception constructor may instead print and abort, if
	// the abort_ flag is set (which is the default).

	// The rule of thumb for trace flag is: if the throwing function
	// is called directly from the Triceps code, then probably
	// there is not much use in the C-level stack backtrace because
	// the more interesting info is the Triceps call sequence and
	// it will be produced by Triceps. If the throwing function is
	// nested somewhere in the user C++ code, the backtrace is more useful
	// because it allows to pinpoint that code. But as always there
	// probably will be exceptions from the rule.

	// The exception will keep the err reference.
	// @param err - the ready Errors reference
	// @param trace - flag: if true, add a stack backtrace as nested Errors
	explicit Exception(Onceref<Errors> err, bool trace);
	// A new Errors object will be constructed from the message.
	// @param err - the error message, may be multiline
	// @param trace - flag: if true, add a stack backtrace as nested Errors
	explicit Exception(const string &err, bool trace);

	// Would not compile without an explicit destructor with throw().
	virtual ~Exception()
		throw();

	// from std::exception
	virtual const char *what();

	// Get the error message in the original structured form.
	virtual Errors *getErrors();

	// Flag: when attempting to create an exception, instead print
	// the message and abort. This behavior is more convenient for
	// debugging of the C++ programs, and is the default one.
	// Also forces the stack trace in the error reports.
	// The interpreted language wrappers should reset it to get the
	// proper exceptions. 
	// Default: true.
	static bool abort_;

	// Flag: enable the backtrace if the constructor requests it.
	// The interpreted language wrappers should reset it to remove
	// the confusion of the C stack traces in the error reports.
	// Default: true.
	static bool enableBacktrace_;

	// Used internally in the unit test: if this is not NULL,
	// instead of calling abort(), the code will set the value
	// at this address to true and return normally.
	static bool *__testAbort_;

protected:
	// Check the trace flag, and append the trace to the error
	// message if it says so.
	// @param trace - the trace flag
	void checkTrace(bool trace);
	// Check the abort_ flag and abort if it says so.
	void checkAbort();

	Erref error_; // the error message
	string what_; // used to keep the return value of what()
};

}; // TRICEPS_NS

#endif // __Triceps_Exception_h__
