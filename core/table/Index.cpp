//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The common interface for indexes.

#include <table/Index.h>
#include <type/TableType.h>

namespace BICEPS_NS {

////////////////////////// Index ///////////////////////////////////

Index::Index(const TableType *tabtype, Table *table) :
	tabType_(tabtype),
	table_(table)
{ }

Index::~Index()
{ }

}; // BICEPS_NS

