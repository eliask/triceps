//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Representation of an ordered set of row types. 

#include <type/RowSetType.h>
#include <common/Exception.h>

namespace TRICEPS_NS {

RowSetType::RowSetType() :
	Type(false, TT_ROWSET),
	errors_(NULL),
	fixed_(false)
{ }

RowSetType *RowSetType::addRow(const string &rname, Autoref<RowType>rtype)
{
	if (fixed_)
		throw Exception("Triceps API violation: attempt to add row '" + rname + "' to a fixed row set type.", true);

	int idx = names_.size();
	if (rname.empty()) {
		if (errors_.isNull())
			errors_ = new Errors;
		errors_->appendMsg(true, strprintf("row name at position %d must not be empty", idx+1));
	} else if (nameMap_.find(rname) != nameMap_.end()) {
		if (errors_.isNull())
			errors_ = new Errors;
		errors_->appendMsg(true, "duplicate row name '" + rname + "'");
	} else if (rtype.isNull()) {
		if (errors_.isNull())
			errors_ = new Errors;
		errors_->appendMsg(true, "null row type with name '" + rname + "'");
	} else {
		names_.push_back(rname);
		types_.push_back(rtype);
		nameMap_[rname] = idx;
	}
	return this;
}

int RowSetType::findName(const string &name) const
{
	NameMap::const_iterator it = nameMap_.find(name);
	if (it != nameMap_.end())
		return it->second;
	else
		return -1;
}

RowType *RowSetType::getRowType(const string &name) const
{
	int idx = findName(name);
	if (idx < 0)
		return NULL;
	else
		return types_[idx];
}

RowType *RowSetType::getRowType(int idx) const
{
	if (idx >= 0 && idx < types_.size())
		return types_[idx];
	else
		return NULL;
}

Erref RowSetType::getErrors() const
{
	return errors_;
}

bool RowSetType::equals(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::equals(t))
		return false;

	const RowSetType *rst = static_cast<const RowSetType *>(t);

	if (names_.size() != rst->names_.size())
		return false;

	size_t i, n = names_.size();
	for (i = 0; i < n; i++) {
		if ( names_[i] != rst->names_[i]
		|| !types_[i]->equals(rst->types_[i]) )
			return false;
	}
	return true;
}

bool RowSetType::match(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::equals(t))
		return false;

	const RowSetType *rst = static_cast<const RowSetType *>(t);

	if (names_.size() != rst->names_.size())
		return false;

	size_t i, n = names_.size();
	for (i = 0; i < n; i++) {
		if ( !types_[i]->match(rst->types_[i]) )
			return false;
	}
	return true;
}

void RowSetType::printTo(string &res, const string &indent, const string &subindent) const
{
	string nextindent;
	const string *passni;
	if (&indent != &NOINDENT) {
		nextindent = indent + subindent;
		passni = &nextindent;
	} else {
		passni = &NOINDENT;
	}

	res.append("rowset {");

	size_t i, n = names_.size();
	for (i = 0; i < n; i++) {
		if (&indent != &NOINDENT) {
			res.append("\n");
			res.append(nextindent);
		} else {
			res.append(" ");
		}
		types_[i]->printTo(res, *passni, subindent);

		res.append(" ");
		res.append(names_[i]);
		res.append(",");
	}
	if (&indent != &NOINDENT) {
		res.append("\n");
		res.append(indent);
	} else {
		res.append(" ");
	}
	res.append("}");
}

}; // TRICEPS_NS
