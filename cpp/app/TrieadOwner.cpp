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
	markDead();
}

void TrieadOwner::markDead()
{
	app_->markTrieadDead(this);
	for (UnitList::iterator it = units_.begin(); it != units_.end(); ++it)
		(*it)->clearLabels();
	units_.clear();
	mainUnit_ = NULL;
	// XXX should also drop references to the app and thread?
	// triead_ = NULL;
	// app_ = NULL;
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

void TrieadOwner::exportNexus(Autoref<Facet> facet, bool import)
{
	const string &name = facet->getFnReturn()->getName();
	if (facet->isImported())
		throw Exception::fTrace("Can not re-export the imported facet '%s' in app '%s' thread '%s'.",
			facet->getFullName().c_str(), app_->getName().c_str(), get()->getName().c_str());
	Erref err = facet->getErrors();
	if (err->hasError()) {
		throw Exception::fTrace(err, "Can not export a facet '%s' with an error in app '%s' thread '%s':",
			name.c_str(), app_->getName().c_str(), get()->getName().c_str());
	}
	Autoref<Nexus> nexus = new Nexus(get()->getName(), facet);
	triead_->exportNexus(app_->getName(), nexus); // adds to the map or throws if duplicate
	if (import) {
		facet->reimport(nexus, get()->getName());
		if (facets_.find(facet->getFullName()) != facets_.end())
			throw Exception::fTrace("On exporting a facet in app '%s' found a same-named facet '%s' already imported, did you mess with the funny names?",
				app_->getName().c_str(), facet->getFullName().c_str());
		facets_[facet->getFullName()] = facet;
	}
}

}; // TRICEPS_NS
