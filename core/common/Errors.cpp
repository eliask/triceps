//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A common way for reporting of the errors

#include <common/Common.h>
#include <assert.h>

namespace BICEPS_NS {

Errors::Errors(bool e) :
	error_(e)
{ };

bool Errors::append(Autoref<Errors> clde)
{
	if (clde.isNull())
		return false;

	bool ce = clde->error_;
	error_ = (error_ || ce);

	if (clde->isEmpty()) // nothing in there
		return ce;

	assert(clde->sibling_.isNull());

	if (clast_.isNull()) {
		cfirst_ = clde;
	} else {
		clast_->sibling_ = clde;
	}
	clast_ = clde;

	return ce;
}

void Errors::appendMsg(bool e, const string &msg)
{
	error_ = (error_ || e);
	push_back(msg);
}

bool Errors::isEmpty()
{
	if (!empty())
		return false;
	if (cfirst_.isNull())
		return true;

	for (Errors *p = cfirst_; p != NULL; p = p->sibling_) {
		if (!p->isEmpty())
			return false;
	}
	return true;
}

void Errors::printTo(string &res, const string &indent, const string &subindent)
{
	size_t i, n = size();
	for (i = 0; i < n; i++) {
		res += indent + at(i) + "\n";
	}
	string downindent = indent + subindent;
	for (Errors *p = cfirst_; p != NULL; p = p->sibling_) {
		p->printTo(res, downindent, subindent);
	}
}

string Errors::print(const string &indent, const string &subindent)
{
	string res;
	printTo(res, indent, subindent);
	return res;
}

}; // BICEPS_NS
