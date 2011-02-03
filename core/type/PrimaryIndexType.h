//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// An index that implements a unique primary key with an unpredictable order.

#ifndef __Biceps_PrimaryIndexType_h__
#define __Biceps_PrimaryIndexType_h__

#include <type/IndexType.h>
#include <type/NameSet.h>

namespace BICEPS_NS {

class PrimaryIndexType : public IndexType
{
public:
	PrimaryIndexType(NameSet *key = NULL);

	PrimaryIndexType *setKey(NameSet *key);

	// from Type
	virtual Erref getErrors() const; 
	virtual bool equals(const Type *t) const;
	virtual bool match(const Type *t) const;
	virtual void printTo(string &res, const string &indent = "", const string &subindent = "  ") const;

	// from IndexType
	virtual IndexType *copy();
	virtual void initialize(TableType *tabtype);
	virtual Index *makeIndex(TableType *tabtype);

protected:
	// used by copy()
	PrimaryIndexType(const PrimaryIndexType &orig);

	Autoref<NameSet> key_;
	Erref errors_;
	intptr_t rhOffset_; // offset of this index's data in table's row handle
	vector<int32_t> keyFld_; // indexes of key fields in the record
};

}; // BICEPS_NS

#endif // __Biceps_PrimaryIndexType_h__
