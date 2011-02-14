//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A special service index type that represents the root of the index type
// tree in a table type.

#include <type/RootIndexType.h>
#include <type/TableType.h>
// #include <table/RootIndex.h>

namespace BICEPS_NS {

RootIndexType::RootIndexType() :
	IndexType(IT_ROOT)
{
}

RootIndexType::RootIndexType(const RootIndexType &orig) :
	IndexType(orig)
{
}

RootIndexType::~RootIndexType()
{ }

void RootIndexType::printTo(string &res, const string &indent, const string &subindent) const
{
	if (nested_.empty()) {
		res.append("{ }"); // make sure that the braces are always present
	} else {
		nested_.printTo(res, indent, subindent);
	}
}

IndexType *RootIndexType::copy() const
{
	return new RootIndexType(*this);
}

void RootIndexType::initialize(TableType *tabtype)
{
	initialized_ = true;
}

Index *RootIndexType::makeIndex(const TableType *tabtype, Table *table) const
{
	// XXX maybe there should be a fake RootIndex?
	return NULL; // can't create anything
}

void RootIndexType::initRowHandleSection(RowHandle *rh) const
{ }

void RootIndexType::clearRowHandleSection(RowHandle *rh) const
{ }

void RootIndexType::copyRowHandleSection(RowHandle *rh, const RowHandle *fromrh) const
{ }

}; // BICEPS_NS
