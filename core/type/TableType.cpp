//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Type for the tables.

#include <type/TableType.h>

namespace BICEPS_NS {

TableType::TableType(Onceref<RowType> rt) :
	Type(false, TT_TABLE),
	rowType_(rt)
{ }

TableType::~TableType()
{ }

TableType *TableType::addIndex(const string &name, IndexType *index)
{
	topInd_.push_back(IndexRef(name, index));
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

	size_t n = topInd_.size();
	if (n != tt->topInd_.size())
		return false;

	for (size_t i = 0; i < n; ++i)
		if (topInd_[i].name_ != tt->topInd_[i].name_
		|| !topInd_[i].index_->equals(tt->topInd_[i].index_))
			return false;
	return true;
}

bool TableType::match(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::match(t))
		return false;
	
	const TableType *tt = static_cast<const TableType *>(t);

	size_t n = topInd_.size();
	if (n != tt->topInd_.size())
		return false;

	for (size_t i = 0; i < n; ++i)
		if (!topInd_[i].index_->match(tt->topInd_[i].index_))
			return false;
	return true;
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
	res.append(") {");
	for (IndexVec::const_iterator i = topInd_.begin(); i != topInd_.end(); ++i) {
		if (&indent != &NOINDENT) {
			res.append("\n");
			res.append(nextindent);
		} else {
			res.append(" ");
		}
		i->index_->printTo(res, *passni, subindent);
		res.append(","); // extra comma after last field doesn't hurt
	}
	if (&indent != &NOINDENT) {
		res.append("\n");
		res.append(nextindent);
	} else {
		res.append(" ");
	}
	res.append("}");
}

}; // BICEPS_NS
