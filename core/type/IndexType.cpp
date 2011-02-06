//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Type for creation of indexes in the tables.

#include <type/IndexType.h>
#include <table/Index.h>
#include <set>

namespace BICEPS_NS {

/////////////////////// IndexTypeRef ////////////////////////////

IndexTypeRef::IndexTypeRef(const string &n, IndexType *it) :
	name_(n),
	index_(it)
{ }

IndexTypeRef::IndexTypeRef()
{ }

/*
IndexTypeRef::IndexTypeRef(const IndexTypeRef &orig) :
	name_(orig.name_),
	index_(orig.index_)
{ }
*/

/////////////////////// IndexTypeVec ////////////////////////////

IndexTypeVec::IndexTypeVec()
{ }

IndexTypeVec::IndexTypeVec(size_t size):
	vector<IndexTypeRef>(size)
{ }

IndexTypeVec::IndexTypeVec(const IndexTypeVec &orig)
{
	size_t n = orig.size();
	for (size_t i = 0; i < n; i++) 
		push_back(IndexTypeRef(orig[i].name_, orig[i].index_->copy()));
}

void IndexTypeVec::initialize(TableType *tabtype, Erref parentErr)
{
	if (!checkDups(parentErr))
		return;

	size_t n = size();
	for (size_t i = 0; i < n; i++) {
		if (at(i).name_.empty()) {
			parentErr->appendMsg(true, strprintf("nested index %d is not allowed to have an empty name\n", (int)i+1));
			continue;
		}
		if (at(i).index_.isNull()) {
			parentErr->appendMsg(true, strprintf("nested index %d '%s' reference must not be NULL\n", (int)i+1, at(i).name_.c_str()));
			continue;
		}
		at(i).index_->initialize(tabtype);
		Erref se = at(i).index_->getErrors();

		parentErr->append(strprintf("nested index %d '%s':\n", (int)i+1, at(i).name_.c_str()), se);
	}
}

void IndexTypeVec::makeIndexes(const TableType *tabtype, Table *table, IndexVec *ivec) const
{
	size_t n = size();
	for (size_t i = 0; i < n; i++) {
		ivec->push_back(IndexRef((*this)[i].name_, (*this)[i].index_->makeIndex(tabtype, table)));
	}
}

bool IndexTypeVec::checkDups(Erref parentErr)
{
	size_t n = size();
	if (n == 0)
		return true;

	set<string> known;

	bool res = true;
	for (size_t i = 0; i < n; i++) {
		const string &name = at(i).name_;
		if (known.find(name) != known.end()) {
			parentErr->appendMsg(true, strprintf("nested index %d name '%s' is used more than once\n", (int)i+1, name.c_str()));
			res = false;
		}
		known.insert(name);
	}
	return res;
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
		fprintf(stderr, "Biceps API violation: index type %p has been already iniitialized and can not be changed\n", this);
		abort();
	}
	nested_.push_back(IndexTypeRef(name, index));
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

IndexVec *IndexType::getIndexVec(Index *ind)
{
	return &ind->nested_;
}

}; // BICEPS_NS
