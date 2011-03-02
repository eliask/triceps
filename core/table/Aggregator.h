//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The base class for aggregators.

#ifndef __Biceps_Aggregator_h__
#define __Biceps_Aggregator_h__

// #include <common/Common.h>

namespace BICEPS_NS {

// The Aggregator is always owned by the index group (OK, logically it can be thought
// that it's owned by an index but really by a group), which always works single-threaded.
// So there is not much point in recfounting it, and this saves a few bytes pre instance.
class Aggregator
{
public:
	virtual ~Aggregator();
};

}; // BICEPS_NS

#endif // __Biceps_Aggregator_h__
