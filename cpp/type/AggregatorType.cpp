//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The base class of user-defined factory of user-defined aggregators.

#include <type/AggregatorType.h>
#include <type/TableType.h>
#include <sched/AggregatorGadget.h>

namespace TRICEPS_NS {

AggregatorType::AggregatorType(const string &name, const RowType *rt) :
	Type(false, TT_AGGREGATOR),
	rowType_(rt),
	name_(name),
	pos_(-1),
	initialized_(false)
{ 
	assert(rt != NULL);
}

AggregatorType::AggregatorType(const AggregatorType &agg) :
	Type(false, TT_AGGREGATOR),
	rowType_(agg.rowType_),
	name_(agg.name_),
	pos_(-1),
	initialized_(false)
{ }

AggregatorType::~AggregatorType()
{ }

void AggregatorType::initialize(TableType *tabtype, IndexType *intype)
{
	initialized_ = true;
}

Erref AggregatorType::getErrors() const
{
	return errors_;
}

void AggregatorType::printTo(string &res, const string &indent, const string &subindent) const
{
	string nextindent;
	const string *passni;
	if (&indent != &NOINDENT) {
		nextindent = indent + subindent;
		passni = &nextindent;
	} else {
		passni = &NOINDENT;
	}

	res.append("aggregator (");

	if (&indent != &NOINDENT) {
		res.append("\n");
		res.append(nextindent);
	} else {
		res.append(" ");
	}
	rowType_->printTo(res, *passni, subindent);

	if (&indent != &NOINDENT) {
		res.append("\n");
		res.append(indent);
	} else {
		res.append(" ");
	}

	
	res.append(") ");
}

}; // TRICEPS_NS
