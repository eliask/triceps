//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Type for creation of indexes in the tables.

#include <type/IndexType.h>

namespace BICEPS_NS {

IndexType::IndexType(IndexId it) :
	Type(false, TT_INDEX),
	table_(NULL),
	parent_(NULL),
	indexId_(it)
{ }

IndexType *IndexType::addNested(const string &name, IndexType *index)
{
	nested_.push_back(IndexRef(name, index));
	return this;
}

}; // BICEPS_NS
