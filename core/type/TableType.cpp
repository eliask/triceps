//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Type for the tables.

#include <type/TableType.h>
#include <type/RootIndexType.h>
#include <table/Table.h>

namespace BICEPS_NS {

TableType::TableType(Onceref<RowType> rt) :
	Type(false, TT_TABLE),
	root_(new RootIndexType),
	rowType_(rt),
	initialized_(false)
{ }

TableType::~TableType()
{ }

TableType *TableType::addIndex(const string &name, IndexType *index)
{
	if (initialized_) {
		fprintf(stderr, "Biceps API violation: table type %p has been already iniitialized and can not be changed\n", this);
		abort();
	}
	root_->addNested(name, index);
	return this;
}

Erref TableType::getErrors() const
{
	return errors_;
}

bool TableType::equals(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::equals(t))
		return false;
	
	const TableType *tt = static_cast<const TableType *>(t);

	return root_->equals(tt->root_);
}

bool TableType::match(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::match(t))
		return false;
	
	const TableType *tt = static_cast<const TableType *>(t);

	return root_->match(tt->root_);
}

void TableType::printTo(string &res, const string &indent, const string &subindent) const
{
	string nextindent;
	const string *passni;
	if (&indent != &NOINDENT) {
		nextindent = indent + subindent;
		passni = &nextindent;
	} else {
		passni = &NOINDENT;
	}

	res.append("table (");
	if (rowType_) {
		if (&indent != &NOINDENT) {
			res.append("\n");
			res.append(nextindent);
		} else {
			res.append(" ");
		}
		rowType_->printTo(res, *passni, subindent);
	}
	if (&indent != &NOINDENT) {
		res.append("\n");
		res.append(indent);
	} else {
		res.append(" ");
	}

	
	res.append(") ");
	root_->printTo(res, indent, subindent);
}

void TableType::initialize()
{
	if (initialized_)
		return; // nothing to do
	initialized_ = true;

	errors_ = new Errors;

	if (rowType_.isNull()) {
		errors_->appendMsg(true, "the row type is not set");
		return;
	}

	errors_->append("row type error:", rowType_->getErrors());

	rhType_ = new RowHandleType;

	// XXX should it check that there is at least one index?
	root_->setNestPos(this, NULL, 0);
	root_->initialize();
	root_->initializeNested();
	errors_->append("index error:", root_->getErrors());

	if (!errors_->hasError() && errors_->isEmpty())
		errors_ = NULL;
}

Onceref<Table> TableType::makeTable(Unit *unit, Gadget::EnqMode emode, const string &name, const string &inputName) const
{
	if (!initialized_ || errors_->hasError())
		return NULL;

	return new Table(unit, emode, name, inputName, this, rowType_, rhType_);
}

IndexType *TableType::findIndex(const string &name) const
{
	if (root_.isNull())
		return NULL;
	return root_->findNested(name);
}

IndexType *TableType::findIndexByIndexId(IndexType::IndexId it) const
{
	if (root_.isNull())
		return NULL;
	return root_->findNestedByIndexId(it);
}

}; // BICEPS_NS
