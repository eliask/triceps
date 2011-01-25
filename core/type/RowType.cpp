//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The row type definition.

#include <type/RowType.h>
#include <map>

namespace BICEPS_NS {


////////////////////// RowType::Field ////////////////////////

RowType::Field::Field() :
	arsz_(0)
{ }

// the default copy and assignment are good enough

RowType::Field::Field(const string &name, Autoref<const Type> t, int arsz) :
	name_(name),
	type_(t),
	arsz_(arsz)
{ }

////////////////////// RowType ////////////////////////

RowType::RowType(const vector<Field> &fields) :
	Type(false, TT_ROW),
	fields_(fields)
{ 
	errors_ = parse();
}

const RowType::Field *RowType::find(const string &fname) const
{
	IdMap::const_iterator it = idmap_.find(fname);
	if (it == idmap_.end())
		return NULL;
	else
		return &fields_[it->second];
}

int RowType::findIdx(const string &fname) const
{
	IdMap::const_iterator it = idmap_.find(fname);
	if (it == idmap_.end())
		return -1;
	else
		return it->second;
}

int RowType::fieldCount() const
{
	return (int)fields_.size();
}

Erref RowType::getErrors() const
{
	return errors_;
}

bool RowType::equals(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::equals(t))
		return false;

	const RowType *rt = static_cast<const RowType *>(t);

	if (fields_.size() != rt->fields_.size())
		return false;

	size_t i, n = fields_.size();
	for (i = 0; i < n; i++) {
		if ( fields_[i].name_ != rt->fields_[i].name_
		|| !fields_[i].type_->equals(rt->fields_[i].type_) 
		|| fields_[i].arsz_ != rt->fields_[i].arsz_ )
			return false;
	}
	return true;
}

bool RowType::match(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::equals(t))
		return false;

	const RowType *rt = static_cast<const RowType *>(t);

	if (fields_.size() != rt->fields_.size())
		return false;

	size_t i, n = fields_.size();
	for (i = 0; i < n; i++) {
		if ( !fields_[i].type_->match(rt->fields_[i].type_) 
		|| fields_[i].arsz_ != rt->fields_[i].arsz_ )
			return false;
	}
	return true;
}


Erref RowType::parse()
{
	Erref err = new Errors;

	size_t i, n = fields_.size();

	idmap_.clear();
	for (i = 0; i < n; i++) {
		const string &name = fields_[i].name_;

		if (name.empty()) {
			err->appendMsg(true, strprintf("field %d name must not be empty\n", (int)i+1));
			continue;
		}

		if (idmap_.find(name) != idmap_.end())  {
			err->appendMsg(true, strprintf("duplicate field name '%s' for fields %d and %d\n",
				name.c_str(), (int)i+1, (int)(idmap_[name])+1));
		} else {
			idmap_[name] = i;
		}

		const Type *t = fields_[i].type_;
		if (!t->isSimple()) {
			err->appendMsg(true, strprintf("field '%s' type must be a simple type\n",
				name.c_str()));
		} else if(t->getTypeId() == TT_VOID) {
			err->appendMsg(true, strprintf("field '%s' type must not be void\n",
				name.c_str()));
		}
	}

	if (err->isEmpty())
		err = NULL; // if no errors, save space
	return err;
}

void RowType::splitInto(const Row *row, FdataVec &data) const
{
	int n = (int)fields_.size();
	data.resize(n);
	for (int i = 0; i < n; i++) {
		data[i].setFrom(this, row, i);
	}
}

Onceref<Row> RowType::copyRow(const RowType *rtype, const Row *row) const
{
	FdataVec v;
	rtype->splitInto(row, v);
	if (v.size() > fields_.size())
		v.resize(fields_.size()); // truncate if too long
	return makeRow(v);
}

void RowType::fillFdata(FdataVec &v, int nf)
{
	int oldsz = (int) v.size();
	if (oldsz < nf) {
		v.resize(nf);
		for (int i = oldsz; i < nf; i++)
			v[i].notNull_ = false;
	}
}

}; // BICEPS_NS
