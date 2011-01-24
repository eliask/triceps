//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The basic underlying row.

#ifndef __Biceps_Row_h__
#define __Biceps_Row_h__

#include <mem/MtBuffer.h>

namespace BICEPS_NS {

// For now, the basic row is nothing but an opaque buffer.
//
// The current approach is that there aren't any common meta-data carried in the
// row, it just knows how to carry the fields. So there is nothing much in
// common between the row formats.
class Row : public MtBuffer
{ };

}; // BICEPS_NS

#endif // __Biceps_Row_h__
