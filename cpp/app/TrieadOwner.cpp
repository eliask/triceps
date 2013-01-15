//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//

#include <app/TrieadOwner.h>

namespace TRICEPS_NS {

TrieadOwner::TrieadOwner(App *app, Triead *th) :
	app_(app),
	triead_(th),
	mainUnit_(new Unit(th->getName()))
{
	units_.push_back(mainUnit_);
}

TrieadOwner::~TrieadOwner()
{
	for (UnitList::iterator it = units_.begin(); it != units_.end(); ++it)
		(*it)->clearLabels();
}

void TrieadOwner::addUnit(Autoref<Unit> u)
{
	for (UnitList::iterator it = units_.begin(); it != units_.end(); ++it) {
		if (*it == u)
			return; // a repeated insert, ignore
	}
	units_.push_back(u);
}

bool TrieadOwner::forgetUnit(Unit *u)
{
	if (u == mainUnit_)
		return false; // can not forget the main unit

	for (UnitList::iterator it = units_.begin(); it != units_.end(); ++it) {
		if (it->get() == u) {
			units_.erase(it);
			return true;
		}
	}
	return false;
}

}; // TRICEPS_NS
