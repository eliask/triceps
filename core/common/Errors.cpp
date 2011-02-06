//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A common way for reporting of the errors

#include <common/Common.h>
#include <assert.h>

namespace BICEPS_NS {

Errors::Epair::Epair()
{ }

Errors::Epair::Epair(const string &msg, Autoref<Errors> child) :
	msg_(msg),
	child_(child)
{ }

Errors::Errors(bool e) :
	error_(e)
{ };

bool Errors::append(const string &msg, Autoref<Errors> clde)
{
	if (clde.isNull())
		return false;

	bool ce = clde->error_;
	error_ = (error_ || ce);

	if (clde->isEmpty()) { // nothing in there
		if (ce) { // but there was an error indication, so append the message
			elist_.push_back(Epair(msg, NULL));
		}
		return ce;
	}

	elist_.push_back(Epair(msg, clde));

	return true;
}

void Errors::appendMsg(bool e, const string &msg)
{
	error_ = (error_ || e);
	elist_.push_back(Epair(msg, NULL));
}

void Errors::replaceMsg(const string &msg)
{
	size_t n = elist_.size();
	if (n != 0)
		elist_[n-1].msg_ = msg;
}

bool Errors::isEmpty()
{
	if (this == NULL)
		return true;

	return elist_.empty();
}

void Errors::printTo(string &res, const string &indent, const string &subindent)
{
	size_t i, n = elist_.size();
	for (i = 0; i < n; i++) {
		if  (!elist_[i].msg_.empty())
			res += indent + elist_[i].msg_ + "\n";
		if  (!elist_[i].child_.isNull())
			elist_[i].child_->printTo(res, indent + subindent, subindent);
	}
}

string Errors::print(const string &indent, const string &subindent)
{
	string res;
	printTo(res, indent, subindent);
	return res;
}

}; // BICEPS_NS
