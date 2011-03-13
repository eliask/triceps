//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// An index that implements a unique primary key with an unpredictable order.

#include <type/FifoIndexType.h>
#include <type/TableType.h>
#include <table/FifoIndex.h>
#include <table/Table.h>

namespace BICEPS_NS {

FifoIndexType::FifoIndexType(size_t limit, bool jumping) :
	IndexType(IT_FIFO),
	limit_(limit),
	jumping_(jumping)
{ 
}

FifoIndexType::FifoIndexType(const FifoIndexType &orig) :
	IndexType(orig),
	limit_(orig.limit_),
	jumping_(orig.jumping_)
{
}

bool FifoIndexType::equals(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!IndexType::equals(t))
		return false;
	
	const FifoIndexType *fit = static_cast<const FifoIndexType *>(t);

	return (limit_ == fit->limit_ && jumping_ == fit->jumping_);
}

void FifoIndexType::printTo(string &res, const string &indent, const string &subindent) const
{
	res.append("FifoIndex(");
	if (limit_ != 0)
		res.append(strprintf("limit=%zd", limit_));
	if (jumping_)
		res.append(" jumping");
	res.append(")");
}

IndexType *FifoIndexType::copy() const
{
	return new FifoIndexType(*this);
}

void FifoIndexType::initialize()
{
	if (isInitialized())
		return; // nothing to do
	initialized_ = true;

	errors_ = new Errors;

	if (nested_.size() != 0)
		errors_->appendMsg(true, "FifoIndexType currently does not support further nested indexes");

	if (limit_ == 0 && jumping_)
		errors_->appendMsg(true, "FifoIndexType requires a non-0 limit for the jumping mode");

	rhOffset_ = tabtype_->rhType()->allocate(sizeof(FifoIndex::RhSection));

	if (!errors_->hasError() && errors_->isEmpty())
		errors_ = NULL;
}

Index *FifoIndexType::makeIndex(const TableType *tabtype, Table *table) const
{
	if (!isInitialized() 
	|| errors_->hasError())
		return NULL; 
	return new FifoIndex(tabtype, table, this);
}

void FifoIndexType::initRowHandleSection(RowHandle *rh) const
{
	RhSection *rs = getSection(rh);
	rs->prev_ = 0;
	rs->next_ = 0;
}

void FifoIndexType::clearRowHandleSection(RowHandle *rh) const
{ } // no dynamic references, nothing to clear

void FifoIndexType::copyRowHandleSection(RowHandle *rh, const RowHandle *fromrh) const
{
	FifoIndexType::initRowHandle(rh); // no cached data, just clear it out
}

}; // BICEPS_NS
