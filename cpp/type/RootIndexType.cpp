//
// (C) Copyright 2011 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A special service index type that represents the root of the index type
// tree in a table type.

#include <type/RootIndexType.h>
#include <type/TableType.h>
#include <table/RootIndex.h>
// #include <table/RootIndex.h>

namespace TRICEPS_NS {

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
		res.append(" { }"); // make sure that the braces are always present
	}
	printSubelementsTo(res, indent, subindent);
}

const_Onceref<NameSet> RootIndexType::getKey() const
{
	return const_Onceref<NameSet>(); // NULL, no keys
}

IndexType *RootIndexType::copy() const
{
	return new RootIndexType(*this);
}

void RootIndexType::initialize()
{
	initialized_ = true;
}

Index *RootIndexType::makeIndex(const TableType *tabtype, Table *table) const
{
	return new RootIndex(tabtype, table, this);
}

void RootIndexType::initRowHandleSection(RowHandle *rh) const
{ }

void RootIndexType::clearRowHandleSection(RowHandle *rh) const
{ }

void RootIndexType::copyRowHandleSection(RowHandle *rh, const RowHandle *fromrh) const
{ }

}; // TRICEPS_NS
