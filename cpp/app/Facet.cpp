//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A facet represents a nexus imported into a thread.

#include <app/Facet.h>
#include <type/HoldRowTypes.h>

namespace TRICEPS_NS {

Facet::Facet(Onceref<FnReturn> fret, bool writer):
	writer_(writer),
	fret_(fret),
	reverse_(false),
	unicast_(false)
{ 
	if (!fret->isInitialized())
		fret->initialize();
	errefAppend(err_, "Errors in the underlying FnReturn:", fret->getErrors());
}

Facet::Facet(Unit *unit, Autoref<Nexus> nx, const string &fullname, const string &asname, bool writer):
	name_(fullname),
	nexus_(nx),
	writer_(writer),
	fret_(new FnReturn(unit, asname)), // will be filled in the body
	reverse_(nx->isReverse()),
	unicast_(nx->isUnicast())
{
	Autoref<HoldRowTypes> holder = new HoldRowTypes;

	// construct the body of FnReturn
	RowSetType *rst = nx->type_;
	const RowSetType::NameVec &rsnames = rst->getRowNames();
	const RowSetType::RowTypeVec &rstypes = rst->getRowTypes();
	int rsz = rsnames.size();
	for (int i = 0; i < rsz; i++)
		fret_->addLabel(rsnames[i], holder->copy(rstypes[i]));
	fret_->initialize(); // never fails
	
	// this is pretty much a copy of the Nexus constructor logic from Facet
	for (RowTypeMap::iterator it = nx->rowTypes_.begin(); it != nx->rowTypes_.end(); ++it)
		rowTypes_[it->first] = holder->copy(it->second);
	for (TableTypeMap::iterator it = nx->tableTypes_.begin(); it != nx->tableTypes_.end(); ++it)
		tableTypes_[it->first] = it->second->deepCopy(holder);
}

Facet *Facet::setReverse(bool on)
{
	assertNotImported();
	reverse_ = on;
	return this;
}

Facet *Facet::setUnicast(bool on)
{
	assertNotImported();
	unicast_ = on;
	return this;
}

Facet *Facet::exportRowType(const string &name, Onceref<RowType> rtype)
{
	assertNotImported();
	if (rtype.isNull()) {
		errefF(err_, "Can not export a NULL row type with name '%s'.", name.c_str());
		return this;
	}
	if (errefAppend(err_, "Can not export a row type '" + name + "' containing errors:", rtype->getErrors()))
		return this;

	if (name.empty()) {
		errefF(err_, "Can not export a row type with an empty name.");
	} else if (rowTypes_.find(name) != rowTypes_.end()) {
		errefF(err_, "Can not export a duplicate row type name '%s'.", name.c_str());
	} else {
		rowTypes_[name] = rtype;
	}
	return this;
}

Facet *Facet::exportTableType(const string &name, Onceref<TableType> tt)
{
	assertNotImported();
	if (tt.isNull()) {
		errefF(err_, "Can not export a NULL table type with name '%s'.", name.c_str());
		return this;
	}
	tt->initialize();
	if (errefAppend(err_, "Can not export a table type '" + name + "' containing errors:", tt->getErrors()))
		return this;

	if (name.empty()) {
		errefF(err_, "Can not export a table type with an empty name.");
	} else if (tableTypes_.find(name) != tableTypes_.end()) {
		errefF(err_, "Can not export a duplicate table type name '%s'.", name.c_str());
	} else {
		tableTypes_[name] = tt;
	}
	return this;
}

void Facet::assertNotImported() const
{
	if (isImported())
		throw Exception::fTrace("Triceps API violation: attempted to modify an imported facet '%s'.",
			name_.c_str());
}

void Facet::reimport(Nexus *nexus, const string &tname)
{
	nexus_ = nexus;
	name_ = buildFullName(tname, fret_->getName());
}

}; // TRICEPS_NS
