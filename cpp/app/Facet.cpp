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
	queueLimit_(DEFAULT_QUEUE_LIMIT),
	reverse_(false),
	unicast_(false),
	appReady_(false)
{ 
	if (!fret->isInitialized())
		fret->initialize();
	err_.fAppend(fret->getErrors(), "Errors in the underlying FnReturn:");

	if (writer_ && fret_->isFaceted()) {
		err_.f("The FnReturn is already connected to a writer facet, can not do it twice.");
		writer_ = false; // so that on destruction it won't reset the fret's xtray
	}
}

Facet::Facet(Unit *unit, Autoref<Nexus> nx, const string &fullname, const string &asname, bool writer):
	name_(fullname),
	nexus_(nx),
	writer_(writer),
	fret_(new FnReturn(unit, asname)), // will be filled in the body
	queueLimit_(nx->queueLimit()),
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

	if (writer_) { // set the initial xtray, and thus mark fret_ with it
		Autoref<Xtray> xtr(new Xtray(fret_->getType()));
		fret_->swapXtray(xtr);
	}
}

Facet::~Facet()
{
	if (writer_ && fret_->isFaceted()) {
		Autoref<Xtray> xtr(NULL);
		fret_->swapXtray(xtr);
	}
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

Facet *Facet::setQueueLimit(int limit)
{
	assertNotImported();
	if (limit < 1)
		err_.f("Can not set the queue size limit to %d, must be greater than 0.", limit);
	else 
		queueLimit_ = limit;
	return this;
}

Facet *Facet::exportRowType(const string &name, Onceref<RowType> rtype)
{
	assertNotImported();
	if (rtype.isNull()) {
		err_.f("Can not export a NULL row type with name '%s'.", name.c_str());
		return this;
	}
	if (err_.fAppend(rtype->getErrors(), "Can not export a row type '%s' containing errors:", name.c_str()))
		return this;

	if (name.empty()) {
		err_.f("Can not export a row type with an empty name.");
	} else if (rowTypes_.find(name) != rowTypes_.end()) {
		err_.f("Can not export a duplicate row type name '%s'.", name.c_str());
	} else {
		rowTypes_[name] = rtype;
	}
	return this;
}

Facet *Facet::exportTableType(const string &name, Onceref<TableType> tt)
{
	assertNotImported();
	if (tt.isNull()) {
		err_.f("Can not export a NULL table type with name '%s'.", name.c_str());
		return this;
	}
	tt->initialize();
	if (err_.fAppend(tt->getErrors(), "Can not export a table type '%s' containing errors:", name.c_str()))
		return this;

	if (name.empty()) {
		err_.f("Can not export a table type with an empty name.");
	} else if (tableTypes_.find(name) != tableTypes_.end()) {
		err_.f("Can not export a duplicate table type name '%s'.", name.c_str());
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
	if (writer_) { // set the initial xtray, and thus mark fret_ with it
		if (fret_->isFaceted()) {
			// this has been already checked in the constructor,
			// so it should never happen unless people are very creative
			throw Exception::fTrace("The FnReturn '%s' in thread '%s' is already connected to a writer facet, can not do it twice.",
				fret_->getName().c_str(), tname.c_str());
			writer_ = false; // so that on destruction it won't reset the fret's xtray
		}
		Autoref<Xtray> xtr(new Xtray(fret_->getType()));
		fret_->swapXtray(xtr);
	}
	nexus_ = nexus;
	name_ = buildFullName(tname, fret_->getName());
	queueLimit_ = nexus->queueLimit(); // might have been adjusted for reverse nexus
}

void Facet::connectToNexus(QueEvent *qev)
{
	if (writer_) {
		wr_ = new NexusWriter;
		nexus_->addWriter(wr_);
	} else {
		rd_ = new ReaderQueue(qev, queueLimit_);
		nexus_->addReader(rd_);
	}
}

void Facet::flushWriter()
{
	if (!appReady_) {
		if (nexus_.isNull())
			throw Exception::fTrace("Triceps API violation: attempted to flush a non-exported facet.");
		else
			throw Exception::fTrace("Triceps API violation: attempted to flush the facet '%s' before the App is ready.",
				name_.c_str());
	}
	if (!wr_.isNull() && !fret_->isXtrayEmpty()) {
		Autoref<Xtray> xt = new Xtray(fret_->getType());
		fret_->swapXtray(xt);
		wr_->write(xt);
	}
}

}; // TRICEPS_NS
