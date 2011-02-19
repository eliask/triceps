//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// An index that implements a unique primary key with an unpredictable order.

#include <type/PrimaryIndexType.h>
#include <type/TableType.h>
#include <table/PrimaryIndex.h>
#include <table/PrimaryNestedIndex.h>
#include <table/Table.h>
#include <string.h>

namespace BICEPS_NS {

//////////////////////////// PrimaryIndexType::Less  /////////////////////////

PrimaryIndexType::Less::Less(const RowType *rt, intptr_t rhOffset, const vector<int32_t> &keyFld)  :
	keyFld_(keyFld),
	rt_(rt),
	rhOffset_(rhOffset)
{ }

bool PrimaryIndexType::Less::operator() (const RowHandle *r1, const RowHandle *r2) const 
{
	RhSection *rs1 = r1->get<RhSection>(rhOffset_);
	RhSection *rs2 = r2->get<RhSection>(rhOffset_);

	{
		Hash::SValue hdf= (Hash::SValue)(rs1->hash_ - rs2->hash_);
		if (hdf < 0)
			return true;
		if (hdf > 0)
			return false;
	}

	// if the hashes match, do the full comparison
	int nf = keyFld_.size();
	for (int i = 0; i < nf; i++) {
		int idx = keyFld_[i];
		bool notNull1, notNull2;
		const char *v1, *v2;
		intptr_t len1, len2;

		notNull1 = rt_->getField(r1->getRow(), idx, v1, len1);
		notNull2 = rt_->getField(r2->getRow(), idx, v2, len2);

		// another shortcut
		if (len1 < len2)
			return true;
		if (len1 > len2)
			return false;

		if (len1 != 0) {
			int df = memcmp(v1, v2, len1);
			if (df < 0)
				return true;
			if (df > 0)
				return false;
		}

		// finally check for nulls if all else equal
		if (!notNull1){
			if (notNull2)
				return true;
		} else {
			if (!notNull2)
				return false;
		}
	}

	return false; // gets here only on equal values
}

void PrimaryIndexType::Less::initHash(RowHandle *rh)
{
	Hash::Value hash = Hash::basis_;

	int nf = keyFld_.size();
	for (int i = 0; i < nf; i++) {
		int idx = keyFld_[i];
		const char *v;
		intptr_t len;

		rt_->getField(rh->getRow(), idx, v, len);
		hash = Hash::append(hash, v, len);
	}

	RhSection *rs = rh->get<RhSection>(rhOffset_);
	// initialize the iterator by calling its constructor
	new(rs) RhSection;
	rs->hash_ = hash;
}

//////////////////////////// PrimaryIndexType /////////////////////////

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
	if (!nested_.empty()) {
		res.append(" ");
		nested_.printTo(res, indent, subindent);
	}
}

IndexType *PrimaryIndexType::copy() const
{
	return new PrimaryIndexType(*this);
}

void PrimaryIndexType::initialize()
{
	if (isInitialized())
		return; // nothing to do
	initialized_ = true;

	errors_ = new Errors;

	rhOffset_ = tabtype_->rhType()->allocate(sizeof(PrimaryIndex::RhSection));

	// find the fields
	const RowType *rt = tabtype_->rowType();
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
	
	less_ = new Less(tabtype_->rowType(), rhOffset_, keyFld_);
}

Index *PrimaryIndexType::makeIndex(const TableType *tabtype, Table *table) const
{
	if (!isInitialized() 
	|| errors_->hasError())
		return NULL; 
	if (nested_.empty())
		return new PrimaryIndex(tabtype, table, this, less_);
	else
		return new PrimaryNestedIndex(tabtype, table, this, less_);
}

void PrimaryIndexType::initRowHandleSection(RowHandle *rh) const
{
	less_->initHash(rh);
}

void PrimaryIndexType::clearRowHandleSection(RowHandle *rh) const
{ 
	// clear the iterator by calling its destructor
	RhSection *rs = rh->get<RhSection>(rhOffset_);
	rs->~RhSection();
}

void PrimaryIndexType::copyRowHandleSection(RowHandle *rh, const RowHandle *fromrh) const
{
	RhSection *rs = rh->get<RhSection>(rhOffset_);
	RhSection *fromrs = fromrh->get<RhSection>(rhOffset_);
	
	// initialize the iterator by calling its constructor
	new(rs) RhSection;
	// then copy the hash
	rs->hash_ = fromrs->hash_;
}

}; // BICEPS_NS
