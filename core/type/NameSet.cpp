//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// An ordered set of names.

#include <type/NameSet.h>

namespace BICEPS_NS {

NameSet::NameSet()
{ }

NameSet::NameSet(const NameSet &other) :
	vector<string> (other)
{ }

NameSet *NameSet::add(const string &s)
{
	push_back(s);
	return this;
}

bool NameSet::equals(const NameSet *other) const
{
	if (this == other)
		return true;

	size_t n = size();
	if (n != other->size())
		return false;

	for (size_t i = 0; i < n; ++i)
		if ((*this)[i] != (*other)[i])
			return false;
	return true;
}

}; // BICEPS_NS

