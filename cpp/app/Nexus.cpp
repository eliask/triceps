//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Nexus is a communication point between the threads, a set of labels
// for passing data downstream and upstream.

#include <app/Nexus.h>

namespace TRICEPS_NS {

Nexus::Nexus(const string &name) :
	name_(name),
	reverse_(false),
	unicast_(false)
{ }

Nexus *Nexus::setReverse(bool on)
{
	assertNotExported();
	reverse_ = on;
	return this;
}

Nexus *Nexus::setUnicast(bool on)
{
	assertNotExported();
	unicast_ = on;
	return this;
}

Nexus *Nexus::setType(Onceref<RowSetType> rst)
{
	assertNotExported();
	if (!type_.isNull()) {
		errefAppend(err_, "Attempted to set the queue type twice.", NULL);
		err_->appendMsg(true, "The first type:");
		err_->appendMultiline(true, type_->print("  "));
		err_->appendMsg(true, "The second type:");
		err_->appendMultiline(true, rst->print("  "));
		return this;
	}
	Erref err = rst->getErrors();
	if (err->hasError()) {
		errefAppend(err_, "The queue type contains an error:", err);
		return this;
	}
	type_ = rst->deepCopy();
	return this;
}

Nexus *Nexus::addRow(const string &rname, const_Autoref<RowType>rtype)
{
	assertNotExported();
	if (type_.isNull())
		type_ = new RowSetType;
	type_->addRow(rname, rtype);
	return this;
}

Nexus *Nexus::exportRowType(const string &name, Onceref<RowType> rtype)
{
	assertNotExported();
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

Nexus *Nexus::exportTableType(const string &name, Onceref<TableType> tt)
{
	assertNotExported();
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

void Nexus::assertNotExported()
{
	if (isExported())
		throw Exception::fTrace("Triceps API violation: attempted to modify an exported nexus '%s/%s'.",
			tname_.c_str(), name_.c_str());
}

void Nexus::initialize()
{
	if (err_->hasError()) // don't even try to make more progress
		return;

	if (type_.isNull())
		type_ = new RowSetType; // an empty type is OK
		
	if (!type_->isInitialized()) {
		type_->initialize();
		Erref err = type_->getErrors();
		if (err->hasError()) {
			errefAppend(err_, "The queue type contains an error:", err);
		}
	}
}

}; // TRICEPS_NS
