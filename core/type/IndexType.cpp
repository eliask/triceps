//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Type for creation of indexes in the tables.

#include <type/IndexType.h>

namespace BICEPS_NS {

/////////////////////// IndexVec ////////////////////////////

IndexVec::IndexVec()
{ }

IndexVec::IndexVec(size_t size):
	vector<IndexRef>(size)
{ }

void IndexVec::initialize(TableType *tabtype, Erref parentErr)
{
	size_t n = size();
	for (size_t i = 0; i < n; i++) {
		if (at(i).name_.empty()) {
			parentErr->appendMsg(true, strprintf("ERROR: nested index %d is not allowed to have an empty name\n", (int)i+1));
			continue;
		}
		if (at(i).index_.isNull()) {
			parentErr->appendMsg(true, strprintf("ERROR: nested index %d '%s' reference must not be NULL\n", (int)i+1, at(i).name_.c_str()));
			continue;
		}
		at(i).index_.initialize(tabtype);
		Erref se = at(i).index_.getError();
		if (!se.isNull() && !se->isEmpty()) {
			if (se->hasError()) 
				parentErr->appendMsg(true, strprintf("ERROR: nested index %d '%s' contains errors\n", (int)i+1, at(i).name_.c_str()));
			else
				parentErr->appendMsg(false, strprintf("warning: nested index %d '%s' contains warnings\n", (int)i+1, at(i).name_.c_str()));
			parentErr->append(se);
		}
	}
}

IndexVec::IndexVec(const IndexVec &orig)
{
	size_t n = orig.size();
	for (size_t i = 0; i < n; i++) 
		push_back(IndexRef(orig[i].name_, orig[i].index_->copy()));
}

/////////////////////// IndexType ////////////////////////////

IndexType::IndexType(IndexId it) :
	Type(false, TT_INDEX),
	table_(NULL),
	parent_(NULL),
	indexId_(it),
	initialized_(false)
{ }

IndexType::IndexType(const IndexType &orig) :
	Type(false, TT_INDEX),
	nested_(orig.nested_),
	table_(NULL),
	parent_(NULL),
	indexId_(orig.indexId_),
	initialized_(false)
{ 
}

IndexType *IndexType::addNested(const string &name, IndexType *index)
{
	if (initialized_) {
		fprint(stderr, "Biceps API violation: index type %p has been already iniitialized and can not be changed\n", this);
		abort();
	}
	nested_.push_back(IndexRef(name, index));
	return this;
}

Erref IndexType::getErrors() const
{
	return errors_;
}

bool IndexType::equals(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::equals(t))
		return false;
	
	const IndexType *it = static_cast<const IndexType *>(t);
	if (indexId_ != it->getSubtype())
		return false;

	size_t n = nested_.size();
	if (n != it->nested_.size())
		return false;

	for (size_t i = 0; i < n; i++) {
		if (nested_[i].name_ != it->nested_[i].name_
		|| !nested_[i].index_->equals(it->nested_[i].index_))
			return false;
	}
	return true;
}

bool IndexType::match(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::match(t))
		return false;
	
	const IndexType *it = static_cast<const IndexType *>(t);
	if (indexId_ != it->getSubtype())
		return false;

	size_t n = nested_.size();
	if (n != it->nested_.size())
		return false;

	for (size_t i = 0; i < n; i++) {
		if (!nested_[i].index_->match(it->nested_[i].index_))
			return false;
	}
	return true;
}

}; // BICEPS_NS
