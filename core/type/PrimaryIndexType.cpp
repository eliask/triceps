//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// An index that implements a unique primary key with an unpredictable order.

#include <type/PrimaryIndexType.h>

namespace BICEPS_NS {

PrimaryIndexType::PrimaryIndexType(NameSet *key) :
	IndexType(IT_PRIMARY),
	key_(key)
{
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

	if (!Type::equals(t))
		return false;
	
	const IndexType *it = static_cast<const IndexType *>(t);
	if (indexId_ != it->getSubtype())
		return false;

	const PrimaryIndexType *pit = static_cast<const PrimaryIndexType *>(t);
	if ( (!key_.isNull() && pit->key_.isNull())
	|| (key_.isNull() && !pit->key_.isNull()) )
		return false;

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

}; // BICEPS_NS
