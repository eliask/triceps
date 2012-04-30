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

	// The exception will keep the err reference.
	explicit Exception(Onceref<Errors> err);
	// A new Errors object will be constructed from the message.
	explicit Exception(const string &err);

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
	// The interpreted language wrappers should reset it to get the
	// proper exceptions. 
	// Default: true.
	static bool abort_;

	// Used internally in the unit test: if this is not NULL,
	// instead of calling abort(), the code will set the value
	// at this address to true and return normally.
	static bool *__testAbort_;

protected:
	// check the abort_ flag and abort if it says so
	void checkAbort();

	Erref error_; // the error message
	string what_; // used to keep the return value of what()
};

}; // TRICEPS_NS

#endif // __Triceps_Exception_h__
