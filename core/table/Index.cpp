//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The common interface for indexes.

#include <table/Index.h>
#include <type/TableType.h>

namespace BICEPS_NS {

/////////////////////// IndexRef ////////////////////////////

IndexRef::IndexRef(const string &n, Index *i) :
	name_(n),
	index_(i)
{ }
IndexRef::IndexRef()
{ }

/////////////////////// IndexVec ////////////////////////////

IndexVec::IndexVec()
{ }

IndexVec::IndexVec(size_t size):
	vector<IndexRef>(size)
{ }

#if 0 // {
IndexVec::IndexVec(const IndexVec &orig)
{
	size_t n = orig.size();
	for (size_t i = 0; i < n; i++) 
		push_back(IndexRef(orig[i].name_, orig[i].index_->copy()));
}
#endif // }

Index *IndexVec::find(const string &name) const
{
	// since the size is usually pretty small, linear search is fine
	size_t n = size();
	for (size_t i = 0; i < n; i++) 
		if((*this)[i].name_ == name)
			return (*this)[i].index_;
	return NULL;
}

////////////////////////// Index ///////////////////////////////////

Index::Index(const TableType *tabtype, Table *table) :
	tabType_(tabtype),
	table_(table)
{ }

Index::~Index()
{ }

}; // BICEPS_NS

