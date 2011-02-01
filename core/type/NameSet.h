//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// An ordered set of names.

#ifndef __Biceps_NameSet_h__
#define __Biceps_NameSet_h__

#include <common/Common.h>
#include <mem/Starget.h>

namespace BICEPS_NS {

// The ordered set of names gets used to specify subsets of fields,
// in particular, the index keys.
class NameSet : public Starget, public vector<string>
{
public:
	NameSet();
	NameSet(const NameSet &other);

	// for chained initialization
	NameSet *add(const string &s);

	// compare for the exact same set
	bool equals(const NameSet *other) const;
};

}; // BICEPS_NS

#endif // __Biceps_NameSet_h__
