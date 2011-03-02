//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The base class of user-defined factory of user-defined aggregators.

#ifndef __Biceps_AggregatorType_h__
#define __Biceps_AggregatorType_h__

#include <type/Type.h>
#include <sched/Gadget.h>

namespace BICEPS_NS {

class TableType;
class IndexType;
class Table;
class AggregatorGadget;
class Aggregator;

// The AggregatorType subclasses serve as a factory for both the AggregatorGadget
// (one per table) and Aggregator (one per index/group) subclasses.
class AggregatorType : public Type
{
public:
	// @param name - name for aggregators' gadget in the table, will be tablename.name
	// @param rt - type of rows produced by this aggregator, wil be referenced
	AggregatorType(const string &name, const RowType *rt);

	// Get back the name
	const string &getName() const
	{
		return name_;
	}

	// Get back the row type
	const RowType *getRowType() const
	{
		return rtype_;
	}

	// Initialize and validate.
	// If already initialized, must return right away.
	// does not include initialization of pos_ and must not make assumptions
	// whether pos_ has been initialized.
	// XXX add whether the index has been initialized
	//
	// The errors are returned through getErrors().
	//
	// By default just sets the initialization flag.
	//
	// @param tabtype - type of the table where this aggregator belongs
	// @param intype - type of the index on which this aggregation happens
	//        (the set of rows in an index instance are the rows for aggregation)
	virtual void initialize(TableType *tabtype, IndexType *intype);

	bool isInitialized() const
	{
		return initialized_;
	}
	
	// Create an AggregatorGadget subclass, one per table.
	// @param table - table where the gadget is created (get the unit, front half
	//        of the name, row type and enqueueing mode from there)
	// @param intype - type of the index on which this aggregation happens
	//        (the set of rows in an index instance are the rows for aggregation)
	// @return - a newly created gadget of the proper subclass
	virtual AggregatorGadget *makeGadget(Table *table, IndexType *intype) = 0;

	// Create an Aggregator subclass, one per index/group.
	// @param - table where the aggregator is created (will also be passed to all ops)
	// @param - this type's gadget in the table (will also be passed to all ops)
	// @return - a newly created instance of aggregator
	virtual Aggregator *makeAggregator(Table *table, AggregatorGadget *gadget) = 0;

	// from Type
	virtual Erref getErrors() const;
	// subclasses also need to implement printTo()
	// XXX do some common part of printTo() here
	// virtual void printTo(string &res, const string &indent = "", const string &subindent = "  ") const = 0;

protected:
	friend class Table;

	// set the position of this aggregator in table's flat vector
	void setPos(int pos)
	{
		pos_ = pos;
	}
	// get back the position
	int getPos() const
	{
		return pos_;
	}

protected:
	const_Autoref<RowType> rtype_; // row type of result
	Erref errors_; // errors from initialization
	string name_; // name inside the table's dotted namespace
	int pos_; // a table has a flat vector of AggregatorGadgets in it, this is the index for this one (-1 if not set)
	bool initialized_; // flag: already initialized, no future changes
};

}; // BICEPS_NS

#endif // __Biceps_AggregatorType_h__
