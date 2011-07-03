//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// An index that implements a unique primary key with an unpredictable order.

#include <type/HashedIndexType.h>
#include <type/TableType.h>
#include <table/HashedIndex.h>
#include <table/HashedNestedIndex.h>
#include <table/Table.h>
#include <string.h>

namespace TRICEPS_NS {

//////////////////////////// HashedIndexType::Less  /////////////////////////

HashedIndexType::Less::Less(const RowType *rt, intptr_t rhOffset, const vector<int32_t> &keyFld)  :
	keyFld_(keyFld),
	rt_(rt),
	rhOffset_(rhOffset)
{ }

bool HashedIndexType::Less::operator() (const RowHandle *r1, const RowHandle *r2) const 
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

void HashedIndexType::Less::initHash(RowHandle *rh)
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

//////////////////////////// HashedIndexType /////////////////////////

HashedIndexType::HashedIndexType(NameSet *key) :
	IndexType(IT_HASHED),
	key_(key)
{
}

HashedIndexType::HashedIndexType(const HashedIndexType &orig) :
	IndexType(orig)
{
	if (!orig.key_.isNull()) {
		key_ = new NameSet(*orig.key_);
	}
}

HashedIndexType *HashedIndexType::setKey(NameSet *key)
{
	if (initialized_) {
		fprintf(stderr, "Triceps API violation: index type %p has been already iniitialized and can not be changed\n", this);
		abort();
	}
	key_ = key;
	return this;
}

bool HashedIndexType::equals(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!IndexType::equals(t))
		return false;
	
	const HashedIndexType *pit = static_cast<const HashedIndexType *>(t);
	if ( (!key_.isNull() && pit->key_.isNull())
	|| (key_.isNull() && !pit->key_.isNull()) )
		return false;

	return key_->equals(pit->key_);
}

bool HashedIndexType::match(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!IndexType::match(t))
		return false;
	
	const HashedIndexType *pit = static_cast<const HashedIndexType *>(t);
	if ( (!key_.isNull() && pit->key_.isNull())
	|| (key_.isNull() && !pit->key_.isNull()) )
		return false;

	// XXX This is not quite right, it should look up the fields in the
	// row type and see if they match, but there is no row type known yet
	// Does it matter?
	return key_->equals(pit->key_);
}

void HashedIndexType::printTo(string &res, const string &indent, const string &subindent) const
{
	res.append("index HashedIndex(");
	if (key_) {
		for (NameSet::iterator i = key_->begin(); i != key_->end(); ++i) {
			res.append(*i);
			res.append(", "); // extra comma after last field doesn't hurt
		}
	}
	res.append(")");
	printSubelementsTo(res, indent, subindent);
}

IndexType *HashedIndexType::copy() const
{
	return new HashedIndexType(*this);
}

void HashedIndexType::initialize()
{
	if (isInitialized())
		return; // nothing to do
	initialized_ = true;

	errors_ = new Errors;

	rhOffset_ = tabtype_->rhType()->allocate(sizeof(HashedIndex::RhSection));

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

Index *HashedIndexType::makeIndex(const TableType *tabtype, Table *table) const
{
	if (!isInitialized() 
	|| errors_->hasError())
		return NULL; 
	if (nested_.empty())
		return new HashedIndex(tabtype, table, this, less_);
	else
		return new HashedNestedIndex(tabtype, table, this, less_);
}

void HashedIndexType::initRowHandleSection(RowHandle *rh) const
{
	less_->initHash(rh);
}

void HashedIndexType::clearRowHandleSection(RowHandle *rh) const
{ 
	// clear the iterator by calling its destructor
	RhSection *rs = rh->get<RhSection>(rhOffset_);
	rs->~RhSection();
}

void HashedIndexType::copyRowHandleSection(RowHandle *rh, const RowHandle *fromrh) const
{
	RhSection *rs = rh->get<RhSection>(rhOffset_);
	RhSection *fromrs = fromrh->get<RhSection>(rhOffset_);
	
	// initialize the iterator by calling its constructor inside RhSection constructor
	new(rs) RhSection(*fromrs);
}

}; // TRICEPS_NS
