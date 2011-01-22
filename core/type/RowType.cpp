//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The row type definition.

#include <type/RowType.h>
#include <map>

namespace BICEPS_NS {

const RowType::Field *RowType::find(const string &fname)
{
	int idx = findIdx(fname);
	if (idx < 0)
		return NULL;
	else
		return &fields_[idx];
}

int RowType::findIdx(const string &fname)
{
}

Erref RowType::validate()
{
	// should this map be kept and used to find the fields fast?
	map <string, size_t> ids;
	Erref err = new Errors;

	size_t i, n = fields_.size();

	abort(); // XXX implement it, this really needs strprintf()

	return err;
}

}; // BICEPS_NS
