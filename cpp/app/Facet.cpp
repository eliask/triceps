//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A facet represents a nexus imported into a thread.

#include <app/Facet.h>

namespace TRICEPS_NS {

Facet::Facet(Onceref<FnReturn> fret, bool writer):
	writer_(writer),
	fret_(fret)
{ }

Facet *Facet::exportRowType(const string &name, Onceref<RowType> rtype)
{
	assertNotImported();
	if (name.empty()) {
		errefAppend(err_, "Can not export a row type with an empty name.", NULL);
	} else if (rowTypes_.find(name) != rowTypes_.end()) {
		errefAppend(err_, "Can not export a duplicate row type name '" + name + "'.", NULL);
	} else if (rtype.isNull()) {
		errefAppend(err_, "Can not export a NULL row type with name '" + name + "'.", NULL);
	} else {
		rowTypes_[name] = rtype;
	}
	return this;
}

Facet *Facet::exportTableType(const string &name, Onceref<TableType> tt)
{
	assertNotImported();
	if (name.empty()) {
		errefAppend(err_, "Can not export a table type with an empty name.", NULL);
	} else if (tableTypes_.find(name) != tableTypes_.end()) {
		errefAppend(err_, "Can not export a duplicate table type name '" + name + "'.", NULL);
	} else if (tt.isNull()) {
		errefAppend(err_, "Can not export a NULL table type with name '" + name + "'.", NULL);
	} else {
		tableTypes_[name] = tt;
	}
	return this;
}

void Facet::assertNotImported()
{
	if (isImported())
		throw Exception::fTrace("Triceps API violation: attempted to modify an imported facet '%s'.",
			name_.c_str());
}

}; // TRICEPS_NS
