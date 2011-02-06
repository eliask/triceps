//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// An index that implements a unique primary key with an unpredictable order.

#include <type/PrimaryIndexType.h>
#include <type/TableType.h>
#include <table/PrimaryIndex.h>

namespace BICEPS_NS {

PrimaryIndexType::PrimaryIndexType(NameSet *key) :
	IndexType(IT_PRIMARY),
	key_(key)
{
}

PrimaryIndexType::PrimaryIndexType(const PrimaryIndexType &orig) :
	IndexType(orig)
{
	if (!orig.key_.isNull()) {
		key_ = new NameSet(*orig.key_);
	}
}

PrimaryIndexType *PrimaryIndexType::setKey(NameSet *key)
{
	key_ = key;
	return this;
}

Erref PrimaryIndexType::getErrors() const
{
	return errors_;
}

bool PrimaryIndexType::equals(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!IndexType::equals(t))
		return false;
	
	const PrimaryIndexType *pit = static_cast<const PrimaryIndexType *>(t);
	if ( (!key_.isNull() && pit->key_.isNull())
	|| (key_.isNull() && !pit->key_.isNull()) )
		return false;

	return key_->equals(pit->key_);
}

bool PrimaryIndexType::match(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!IndexType::match(t))
		return false;
	
	const PrimaryIndexType *pit = static_cast<const PrimaryIndexType *>(t);
	if ( (!key_.isNull() && pit->key_.isNull())
	|| (key_.isNull() && !pit->key_.isNull()) )
		return false;

	// XXX This is not quite right, it should look up the fields in the
	// row type and see if they match, but there is no row type known yet
	// Does it matter?
	return key_->equals(pit->key_);
}

void PrimaryIndexType::printTo(string &res, const string &indent, const string &subindent) const
{
	res.append("PrimaryIndex(");
	if (key_) {
		for (NameSet::iterator i = key_->begin(); i != key_->end(); ++i) {
			res.append(*i);
			res.append(", "); // extra comma after last field doesn't hurt
		}
	}
	res.append(")");
}

IndexType *PrimaryIndexType::copy() const
{
	return new PrimaryIndexType(*this);
}

void PrimaryIndexType::initialize(TableType *tabtype)
{
	if (isInitialized())
		return; // nothing to do
	initialized_ = true;

	errors_ = new Errors;

	if (nested_.size() != 0)
		errors_->appendMsg(true, "PrimaryIndexType currently does not support further nested indexes");

	rhOffset_ = tabtype->rhType()->allocate(sizeof(PrimaryIndex::RhSection));

	// find the fields
	const RowType *rt = tabtype->rowType();
	int n = key_->size();
	keyFld_.resize(n);
	for (int i = 0; i < n; i++) {
		int idx = rt->findIdx((*key_)[i]);
		if (idx < 0) {
			errors_->appendMsg(true, strprintf("can not find the key field '%s'", (*key_)[i].c_str()));
		}
		keyFld_[i] = idx;
	}
	// XXX should it check that the fields don't repeat?
	
	if (!errors_->hasError() && errors_->isEmpty())
		errors_ = NULL;
}

Index *PrimaryIndexType::makeIndex(const TableType *tabtype, Table *table) const
{
	if (!isInitialized() 
	|| errors_->hasError())
		return NULL; 
	return new PrimaryIndex(tabtype, table, this, new PrimaryIndex::Less(
		tabtype->rowType(), rhOffset_, keyFld_) );
}

}; // BICEPS_NS
