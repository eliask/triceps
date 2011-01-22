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
	if (!ce && clde->empty()) // nothing in there
		return false;

	assert(clde->sibling_.isNull());

	if (clast_.isNull()) {
		cfirst_ = clde;
	} else {
		clast_->sibling_ = clde;
	}
	clast_ = clde;

	error_ = (error_ || ce);
	return ce;
}

void Errors::appendMsg(bool e, const string &msg)
{
	error_ = (error_ || e);
	push_back(msg);
}

}; // BICEPS_NS
