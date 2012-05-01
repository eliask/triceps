//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Exception to propagate the fatal errors through multiple levels of calling.

#include <common/Exception.h>
#include <common/Common.h>

namespace TRICEPS_NS {

bool Exception::abort_ = true;
bool *Exception::__testAbort_ = NULL;

Exception::Exception(Onceref<Errors> err) :
	error_(err)
{
	checkAbort();
}

Exception::Exception(const string &err) :
	error_(new Errors(err))
{
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
