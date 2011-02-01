//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// An index that simply keeps the records in the order entered.

#ifndef __Biceps_FifoIndexType_h__
#define __Biceps_FifoIndexType_h__

#include <type/IndexType.h>

namespace BICEPS_NS {

// It's not much of an index, simply keeping the records in a list.
// But it's useful fo rthings like storing the aggregation groups.
class FifoIndexType : public IndexType
{
public:
};

}; // BICEPS_NS

#endif // __Biceps_FifoIndexType_h__
