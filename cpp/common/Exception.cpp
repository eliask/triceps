//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Exception to propagate the fatal errors through multiple levels of calling.

#include <stdlib.h>
#include <common/Exception.h>
#include <common/Common.h>

#if TRICEPS_BACKTRACE // {
#include <execinfo.h>
#endif // } TRICEPS_BACKTRACE

namespace TRICEPS_NS {

bool Exception::abort_ = true;
bool Exception::enableBacktrace_ = true;
bool *Exception::__testAbort_ = NULL;

Exception::Exception(Onceref<Errors> err, bool trace) :
	error_(err)
{
	checkTrace(trace);
	checkAbort();
}

Exception::Exception(const string &err, bool trace) :
	error_(new Errors(err))
{
	checkTrace(trace);
	checkAbort();
}

Exception::~Exception()
	throw()
{ }

const char *Exception::what()
{
	error_->printTo(what_);
	return what_.c_str();
}

Errors *Exception::getErrors()
{
	return error_.get();
}

void Exception::checkTrace(bool trace)
{
#if TRICEPS_BACKTRACE // {
	if (enableBacktrace_ && (trace || abort_) ) { // if aborting, the stack trace never hurts because the calling labels won't be printed
		void *buffer[100];
		int sz = backtrace(buffer, sizeof(buffer)/sizeof(buffer[0]));
		char **symbols = backtrace_symbols(buffer, sz);
		Erref log(new Errors);
		for (int i = 0; i < sz; i++) {
			log->appendMsg(false, symbols[i]);
		}
		if (sz == sizeof(buffer)/sizeof(buffer[0])) {
			log->appendMsg(false, "..."); // show that the trace is likely incomplete
		}
		free(symbols);
		error_->append("Stack trace:", log);
	}
#endif // } TRICEPS_BACKTRACE
}

void Exception::checkAbort()
{
	if (abort_) {
		error_->printTo(what_, "  ");
		fprintf(stderr, "Triceps fatal error, aborting:\n%s\n", what_.c_str());
		if (__testAbort_ == NULL)
			abort();
		else
			*__testAbort_ = true;
	}
}


}; // TRICEPS_NS
