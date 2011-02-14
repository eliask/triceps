//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Type for creation of indexes in the tables.

#include <type/TableType.h>
#include <type/GroupHandleType.h>
#include <table/Index.h>
#include <set>

namespace BICEPS_NS {

/////////////////////// IndexTypeRef ////////////////////////////

IndexTypeRef::IndexTypeRef(const string &n, IndexType *it) :
	name_(n),
	index_(it)
{ }

IndexTypeRef::IndexTypeRef()
{ }

/*
IndexTypeRef::IndexTypeRef(const IndexTypeRef &orig) :
	name_(orig.name_),
	index_(orig.index_)
{ }
*/

/////////////////////// IndexTypeVec ////////////////////////////

IndexTypeVec::IndexTypeVec()
{ }

IndexTypeVec::IndexTypeVec(size_t size):
	vector<IndexTypeRef>(size)
{ }

IndexTypeVec::IndexTypeVec(const IndexTypeVec &orig)
{
	size_t n = orig.size();
	for (size_t i = 0; i < n; i++) 
		push_back(IndexTypeRef(orig[i].name_, orig[i].index_->copy()));
}

void IndexTypeVec::initialize(TableType *tabtype, Erref parentErr)
{
	if (!checkDups(parentErr))
		return;

	// XXX add a check for loops in the topology (or simply a limit on nesting levels?)

	size_t n = size();
	for (size_t i = 0; i < n; i++) {
		if (at(i).name_.empty()) {
			parentErr->appendMsg(true, strprintf("nested index %d is not allowed to have an empty name", (int)i+1));
			continue;
		}
		if (at(i).index_.isNull()) {
			parentErr->appendMsg(true, strprintf("nested index %d '%s' reference must not be NULL", (int)i+1, at(i).name_.c_str()));
			continue;
		}
		at(i).index_->initialize(tabtype);
	}
	if (parentErr->hasError())
		return; // don't even try the nested stuff
	// do it in the depth-last order
	for (size_t i = 0; i < n; i++) {
		at(i).index_->initializeNested(tabtype);
		Erref se = at(i).index_->getErrors();
		parentErr->append(strprintf("nested index %d '%s':", (int)i+1, at(i).name_.c_str()), se);
	}
}

void IndexTypeVec::makeIndexes(const TableType *tabtype, Table *table, IndexVec *ivec) const
{
	size_t n = size();
	for (size_t i = 0; i < n; i++) {
		ivec->push_back(IndexRef((*this)[i].name_, (*this)[i].index_->makeIndex(tabtype, table)));
	}
}

bool IndexTypeVec::checkDups(Erref parentErr)
{
	size_t n = size();
	if (n == 0)
		return true;

	set<string> known;

	bool res = true;
	for (size_t i = 0; i < n; i++) {
		const string &name = at(i).name_;
		if (known.find(name) != known.end()) {
			parentErr->appendMsg(true, strprintf("nested index %d name '%s' is used more than once", (int)i+1, name.c_str()));
			res = false;
		}
		known.insert(name);
	}
	return res;
}

void IndexTypeVec::printTo(string &res, const string &indent, const string &subindent) const
{
	if (empty())
		return; // print nothing

	string nextindent;
	const string *passni;
	if (&indent != &NOINDENT) {
		nextindent = indent + subindent;
		passni = &nextindent;
	} else {
		passni = &NOINDENT;
	}

	res.append("{");
	for (IndexTypeVec::const_iterator i = begin(); i != end(); ++i) {
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
	} else {
		res.append(" ");
	}
	res.append("}");
}

void IndexTypeVec::initRowHandle(RowHandle *rh) const
{
	size_t n = size();
	for (size_t i = 0; i < n; i++) 
		(*this)[i].index_->initRowHandle(rh);
}

void IndexTypeVec::clearRowHandle(RowHandle *rh) const
{
	size_t n = size();
	for (size_t i = 0; i < n; i++) 
		(*this)[i].index_->clearRowHandle(rh);
}

/////////////////////// IndexType ////////////////////////////

IndexType::IndexType(IndexId it) :
	Type(false, TT_INDEX),
	tabtype_(NULL),
	parent_(NULL),
	indexId_(it),
	initialized_(false)
{ }

IndexType::IndexType(const IndexType &orig) :
	Type(false, TT_INDEX),
	nested_(orig.nested_),
	tabtype_(NULL),
	parent_(NULL),
	indexId_(orig.indexId_),
	initialized_(false)
{ 
}

IndexType::~IndexType()
{ }

IndexType *IndexType::addNested(const string &name, IndexType *index)
{
	if (initialized_) {
		fprintf(stderr, "Biceps API violation: index type %p has been already iniitialized and can not be changed\n", this);
		abort();
	}
	nested_.push_back(IndexTypeRef(name, index));
	return this;
}

Erref IndexType::getErrors() const
{
	return errors_;
}

bool IndexType::equals(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::equals(t))
		return false;
	
	const IndexType *it = static_cast<const IndexType *>(t);
	if (indexId_ != it->getIndexId())
		return false;

	size_t n = nested_.size();
	if (n != it->nested_.size())
		return false;

	for (size_t i = 0; i < n; i++) {
		if (nested_[i].name_ != it->nested_[i].name_
		|| !nested_[i].index_->equals(it->nested_[i].index_))
			return false;
	}
	return true;
}

bool IndexType::match(const Type *t) const
{
	if (this == t)
		return true; // self-comparison, shortcut

	if (!Type::match(t))
		return false;
	
	const IndexType *it = static_cast<const IndexType *>(t);
	if (indexId_ != it->getIndexId())
		return false;

	size_t n = nested_.size();
	if (n != it->nested_.size())
		return false;

	for (size_t i = 0; i < n; i++) {
		if (!nested_[i].index_->match(it->nested_[i].index_))
			return false;
	}
	return true;
}

IndexVec *IndexType::getIndexVec(Index *ind)
{
	return &ind->nested_;
}

void IndexType::initializeNested(TableType *tabtype)
{
	assert(isInitialized());

	if (errors_.isNull())
		errors_ = new Errors;

	int n = (int)nested_.size();

	if (n != 0) {
		// remember, how much of handle was needed to get here
		group_ = new GroupHandleType(*tabtype->rhType()); // copies the current size
		ghOffset_ = group_->allocate(sizeof(GhSection) + (n-1) * sizeof(Index *));
	} else {
		group_ = NULL;
	}

	for (int i = 0; i < n; i++) {
		IndexType *st = nested_[i].index_;
		if (st != 0)
			st->setNestPos(tabtype, this, i);
	}
	nested_.initialize(tabtype, errors_);
	
	// optimize by nullifying the empty error set
	if (!errors_->hasError() && errors_->isEmpty())
		errors_ = NULL;
}

void IndexType::copyGroupHandle(GroupHandle *rh, const RowHandle *fromrh) const
{
	copyRowHandleSection(rh, fromrh);
	if (parent_ != NULL)
		parent_->copyGroupHandle(rh, fromrh);
}

void IndexType::clearGroupHandle(GroupHandle *rh) const
{
	clearRowHandleSection(rh);
	if (parent_ != NULL)
		parent_->clearGroupHandle(rh);
}

GroupHandle *IndexType::makeGroupHandle(const RowHandle *rh, Table *table) const
{
	const Row *r = rh->getRow();
	r->incref();
	GroupHandle *gh = group_->makeHandle(r);
	copyGroupHandle(gh, rh); // copy the key portions

	// now create and connect the sub-indexes
	GhSection *gs = getGhSection(gh);

	gs->size_ = 0; // empty yet

	int n = (int)nested_.size();
	for (int i = 0; i < n; i++) {
		Index *idx = nested_[i].index_->makeIndex(tabtype_, table);
		gs->subidx_[i] = idx;
		idx->incref(); // hold on to it manually
	}

	return gh;
}

void IndexType::destroyGroupHandle(GroupHandle *gh) const
{
	GhSection *gs = getGhSection(gh);

	int n = (int)nested_.size();
	for (int i = 0; i < n; i++) {
		Index *idx = gs->subidx_[i];
		if (idx->decref() <= 0)
			delete idx;
	}

	delete gh;
}

RowHandle *IndexType::beginIteration(GroupHandle *gh) const
{
	if (gh == NULL)
		return NULL;

	GhSection *gs = getGhSection(gh);
	return gs->subidx_[0]->begin();
}

RowHandle *IndexType::nextIteration(GroupHandle *gh, RowHandle *cur) const
{
	if (gh == NULL)
		return NULL;

	GhSection *gs = getGhSection(gh);
	return gs->subidx_[0]->next(cur);
}

Index *IndexType::groupToIndex(GroupHandle *gh, size_t nestPos) const
{
	if (gh == NULL || nestPos >= nested_.size())
		return NULL;

	GhSection *gs = getGhSection(gh);
	return gs->subidx_[nestPos];
}

bool IndexType::groupReplacementPolicy(GroupHandle *gh, RowHandle *rh, RhSet &replaced) const
{
	if (gh == NULL)
		return true;

	GhSection *gs = getGhSection(gh);
	int n = (int)nested_.size();
	for (int i = 0; i < n; i++) {
		if ( !gs->subidx_[i]->replacementPolicy(rh, replaced))
			return false;
	}
	return true;
}

void IndexType::groupInsert(GroupHandle *gh, RowHandle *rh) const
{
	assert(gh != NULL);

	GhSection *gs = getGhSection(gh);
	int n = (int)nested_.size();
	for (int i = 0; i < n; i++) {
		gs->subidx_[i]->insert(rh);
	}
	++gs->size_; // a record got inserted
}

void IndexType::groupRemove(GroupHandle *gh, RowHandle *rh) const
{
	assert(gh != NULL);

	GhSection *gs = getGhSection(gh);
	int n = (int)nested_.size();
	for (int i = 0; i < n; i++) {
		gs->subidx_[i]->remove(rh);
	}
	--gs->size_; // a record got inserted
}

}; // BICEPS_NS
