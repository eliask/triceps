//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The Application class that manages the threads. There may be multiple
// Apps in one program, each with a different name.

#include <string.h>
#include <app/App.h>
#include <app/TrieadOwner.h>
#include <app/Nexus.h>

namespace TRICEPS_NS {

// -------------------- App::TrieadUpd -----------------------------------

void App::TrieadUpd::broadcastL(const string &appname)
{
	int err = cond_.broadcast();
	if (err != 0)
		throw Exception::fTrace("Internal error: condvar broadcast failed in application '%s', errno=%d: %s.", 
			appname.c_str(), err, strerror(err));
}

void App::TrieadUpd::waitL(const string &appname, const string &tname, const timespec &abstime)
{
	int err = cond_.timedwait(abstime);
	if (err != 0) {
		if (err == ETIMEDOUT)
			throw Exception::fTrace("Thread '%s' in application '%s' did not initialize within the deadline.", 
				tname.c_str(), appname.c_str());
		else 
			throw Exception::fTrace("Internal error: condvar wait for thread '%s' in application '%s' failed, errno=%d: %s.", 
				tname.c_str(), appname.c_str(), err, strerror(err));
	}
}

int App::TrieadUpd::_countSleepersL()
{
	return cond_.sleepers_;
}

// -------------------- App ----------------------------------------------

App::Map App::apps_;
pw::pmutex App::apps_mutex_;

Onceref<App> App::make(const string &name)
{
	pw::lockmutex lm(apps_mutex_);

	Map::iterator it = apps_.find(name);
	if (it != apps_.end())
		throw Exception::fTrace("Duplicate Triceps application name '%s' is not allowed.", name.c_str());

	App *a = new App(name);
	apps_[name] = a;
	return a;
}

Onceref<App> App::find(const string &name)
{
	pw::lockmutex lm(apps_mutex_);

	Map::iterator it = apps_.find(name);
	if (it == apps_.end())
		throw Exception::fTrace("Triceps application '%s' is not found.", name.c_str());

	return it->second;
}

void App::listApps(Map &ret)
{
	pw::lockmutex lm(apps_mutex_);

	if (!ret.empty())
		ret.clear();

	// copy a snapshot of the apps map to the return value
	for (Map::iterator it = apps_.begin(); it != apps_.end(); ++it)
		ret.insert(*it);
}

void App::drop(Onceref<App> app)
{
	pw::lockmutex lm(apps_mutex_);

	Map::iterator it = apps_.find(app->name_);
	if (it == apps_.end())
		return;
	if (it->second != app)
		return;
	apps_.erase(it);
}

App::App(const string &name) :
	name_(name),
	ready_(true), // since no threads are unready
	dead_(true), // since no threads are alive
	needHarvest_(true), // "dead" also implies being ready to harvest
	unreadyCnt_(0),
	aliveCnt_(0)
{
	computeDeadline(DEFAULT_TIMEOUT);
}

void App::setTimeout(int sec)
{
	pw::lockmutex lm(mutex_); // needed for the thread count check
	if (!threads_.empty())
		throw Exception::fTrace("Triceps application '%s' deadline can not be changed after the thread creation.", name_.c_str());
	computeDeadline(sec);
}

void App::setDeadline(const timespec &dl)
{
	pw::lockmutex lm(mutex_); // needed for the thread count check
	if (!threads_.empty())
		throw Exception::fTrace("Triceps application '%s' deadline can not be changed after the thread creation.", name_.c_str());
	deadline_ = dl;
}

void App::computeDeadline(int sec)
{
	int err = clock_gettime(CLOCK_REALTIME, &deadline_); // the current time
	if (err != 0) {
		throw Exception::fTrace("Triceps internal error: clock_gettime() failed: err=%d %s.", 
			err, strerror(err));
	}
	deadline_.tv_sec += sec;
}

bool App::isAborted() const
{
	pw::lockmutex lm(mutex_);
	return isAbortedL();
}

string App::getAbortedBy() const
{
	pw::lockmutex lm(mutex_);
	string s = abortedBy_;
	return s;
}

string App::getAbortedMsg() const
{
	pw::lockmutex lm(mutex_);
	string s = abortedMsg_;
	return s;
}

bool App::isDead()
{
	return (dead_.trywait() == 0);
}

void App::waitDead()
{
	dead_.wait();
}

Onceref<TrieadOwner> App::makeTriead(const string &tname)
{
	if (tname.empty())
		throw Exception::fTrace("Empty thread name is not allowed, in application '%s'.", name_.c_str());

	pw::lockmutex lm(mutex_);

	TrieadUpdMap::iterator it = threads_.find(tname);
	TrieadUpd *upd;
	if (it == threads_.end()) {
		upd = new TrieadUpd(mutex_);
		threads_[tname] = upd;
		if (++unreadyCnt_ == 1 && !isAbortedL())
			ready_.reset();
		if (++aliveCnt_ == 1)
			dead_.reset();
	} else {
		upd = it->second;
		if(!upd->t_.isNull())
			throw Exception::fTrace("Duplicate thread name '%s' is not allowed, in application '%s'.", 
				tname.c_str(), name_.c_str());
	}

	Triead *th = new Triead(tname);
	TrieadOwner *ow = new TrieadOwner(this, th);
	upd->t_ = th;

	return ow; // the only owner API for the thread!
}

void App::declareTriead(const string &tname)
{
	if (tname.empty())
		throw Exception::fTrace("Empty thread name is not allowed, in application '%s'.", name_.c_str());

	pw::lockmutex lm(mutex_);
	TrieadUpdMap::iterator it = threads_.find(tname);
	if (it == threads_.end()) {
		threads_[tname] = new TrieadUpd(mutex_);
		if (++unreadyCnt_ == 1 && !isAbortedL())
			ready_.reset();
		if (++aliveCnt_ == 1)
			dead_.reset();
	} // else just do nothing
}

void App::defineJoin(const string &tname, Onceref<TrieadJoin> j)
{
	pw::lockmutex lm(mutex_);

	TrieadUpdMap::iterator it = threads_.find(tname);
	if (it == threads_.end()) {
		throw Exception::fTrace("In Triceps application '%s' can not define a join for an unknown thread '%s'.", 
			name_.c_str(), tname.c_str());
	}
	it->second->j_ = j;
}

void App::assertNotAbortedL() const
{
	if (!abortedBy_.empty())
		throw Exception::fTrace("App '%s' has been aborted by thread '%s': %s",
			name_.c_str(), abortedBy_.c_str(), abortedMsg_.c_str());
}

void App::assertTrieadL(Triead *th) const
{
	TrieadUpdMap::const_iterator it = threads_.find(th->getName());
	if (it == threads_.end()) {
		throw Exception::fTrace("Thread '%s' does not belong to the application '%s'.",
			th->getName().c_str(), name_.c_str());
	}
	if (it->second->t_.get() != th) {
		throw Exception::fTrace("Thread '%s' does not belong to the application '%s', it's same-names but from another app.",
			th->getName().c_str(), name_.c_str());
	}
}

void App::abortBy(const string &tname, const string &msg)
{
	pw::lockmutex lm(mutex_);

	// mark the thread as dead
	TrieadUpdMap::iterator it = threads_.find(tname);
	if (it != threads_.end()) {
		markTrieadDeadL(it->second->t_);
	}

	if (isAbortedL()) // already aborted, nothing more to do
		return;

	abortedBy_ = tname; // mark as aborted
	abortedMsg_ = msg;

	// now wake up all the sleepers
	ready_.signal();
	needHarvest_.signal();
	for (TrieadUpdMap::iterator it = threads_.begin(); it != threads_.end(); ++it) {
		it->second->broadcastL(name_);
	}
}

void App::assertTrieadOwnerL(TrieadOwner *to) const
{
	assertTrieadL(to->get());
}

Onceref<Triead> App::findTriead(TrieadOwner *to, const string &tname, bool immed)
{
	pw::lockmutex lm(mutex_);

	assertNotAbortedL();
	assertTrieadOwnerL(to);

	// A special short-circuit for the self-reference, a thread can
	// find itself even if it's not fully constructed.
	if (to->get()->getName() == tname)
		return to->get();

	// The assertion above makes sure that this succeeds.
	Autoref<TrieadUpd> selfupd = threads_.find(to->get()->getName())->second;
	if (selfupd->waitFor_ != NULL)
		throw Exception::fTrace("In Triceps application '%s' thread '%s' owner object must not be used from 2 OS threads.",
			name_.c_str(), to->get()->getName().c_str());

	TrieadUpdMap::iterator it = threads_.find(tname);
	if (it == threads_.end())
		throw Exception::fTrace("In Triceps application '%s' thread '%s' is referring to a non-existing thread '%s'.",
			name_.c_str(), to->get()->getName().c_str(), tname.c_str());

	Autoref <TrieadUpd> upd = it->second;
	Triead *t = upd->t_;
	if (t != NULL && (immed || t->isConstructed()))
		return t;

	if (immed)
		throw Exception::fTrace("In Triceps application '%s' thread '%s' did an immediate find of a declared but undefined thread '%s'.",
			name_.c_str(), to->get()->getName().c_str(), tname.c_str());

	// Make sure that won't deadlock: go through the dependency
	// chain and ensure that it doesn't return back to our thread.
	// Doing it once up front is enough, because afterwards the responsibility
	// of the deadlock detection will be on the new sleepers.
	for (TrieadUpd *p = upd; p != NULL; p = p->waitFor_) {
		if (p == selfupd.get()) {
			// print the list of dependencies, it repeats the same loop
			Erref trace = new Errors(true);
			for (TrieadUpd *pp = upd; pp != selfupd.get(); pp = pp->waitFor_)
				trace->appendMsg(true, pp->t_->getName() + " waits for " + pp->waitFor_->t_->getName());
			Erref err = new Errors(strprintf(
					"In Triceps application '%s' thread '%s' waiting for thread '%s' would cause a deadlock:",
						name_.c_str(), to->get()->getName().c_str(), tname.c_str()),
				trace);
			throw Exception(err, true);
		}
	}

	selfupd->waitFor_ = upd;
	try {
		do {
			upd->waitL(name_, tname, deadline_); // will throw on timeout
			t = upd->t_;
		} while (!isAbortedL() && (t == NULL || !t->isConstructed()));
		selfupd->waitFor_ = NULL;
	} catch (...) {
		selfupd->waitFor_ = NULL;
		throw;
	}

	assertNotAbortedL();
	return t;
}

Onceref<Nexus> App::findNexus(TrieadOwner *to, const string &tname, const string &nexname, bool immed)
{
	// No App mutex! findTriead() takes care of that.
	Autoref<Triead> t = findTriead(to, tname, immed); // uses App mutex
	return t->findNexus(to->get()->getName(), name_, nexname); // uses Triead mutex
}

void App::markTrieadConstructed(TrieadOwner *to)
{
	pw::lockmutex lm(mutex_);

	Triead *t = to->get();
	assertTrieadL(t); // means the the find below can't fail

	markTrieadConstructedL(t);
}

void App::markTrieadConstructedL(Triead *t)
{
	if (!t->isConstructed()) {
		t->markConstructed();
		TrieadUpdMap::iterator it = threads_.find(t->getName());
		it->second->broadcastL(name_);
	}
}

void App::markTrieadReady(TrieadOwner *to)
{
	pw::lockmutex lm(mutex_);

	Triead *t = to->get();
	assertTrieadL(t);

	markTrieadConstructedL(t);
	markTrieadReadyL(t);
}

void App::markTrieadReadyL(Triead *t)
{
	if (!t->isReady()) {
		t->markReady();
		if (--unreadyCnt_ == 0)
			ready_.signal();
	}
}

void App::markTrieadDead(TrieadOwner *to)
{
	pw::lockmutex lm(mutex_);

	Triead *t = to->get();
	assertTrieadL(t);

	markTrieadConstructedL(t);
	markTrieadReadyL(t);
	markTrieadDeadL(t);
}

void App::markTrieadDeadL(Triead *t)
{
	if (!t->isDead()) {
		t->markDead();
		if (--aliveCnt_ == 0) {
			dead_.signal();
			needHarvest_.signal();
		}

		TrieadUpdMap::iterator it = threads_.find(t->getName());
		// should never fail but check just in case
		if (it != threads_.end()) {
			TrieadUpd *upd = it->second;
			if (upd->j_) {
				zombies_.push_back(upd);
				needHarvest_.signal();
			}
		}
	}
}

bool App::harvestOnce()
{
	while(true) {
		Autoref<TrieadJoin> j;
		{
			pw::lockmutex lm(mutex_);
			if (zombies_.empty()) {
				bool dead = isDead();
				if (!dead)
					needHarvest_.reset();
				return dead;
			}
			TrieadUpd *upd = zombies_.front();
			j = upd->j_;
			upd->j_ = NULL; // guarantees that will be joined only once
			zombies_.pop_front();
		}
		if (!j.isNull()) // should never be NULL, but just in case
			j->join();
	}
}

void App::waitNeedHarvest()
{
	needHarvest_.wait();
}

void App::harvester(bool throwAbort)
{
	string appName, abThread, abMsg;

	bool dead = false;
	while (!dead) {
		waitNeedHarvest();
		dead = harvestOnce();
	}
	appName = name_;
	abThread = abortedBy_;
	abMsg = abortedMsg_;
	drop(this);

	if (throwAbort && !abThread.empty())
		throw Exception::fTrace("App '%s' has been aborted by thread '%s': %s",
			appName.c_str(), abThread.c_str(), abMsg.c_str());
}

bool App::isReady()
{
	return (ready_.trywait() == 0);
}

void App::waitReady()
{
	{
		pw::lockmutex lm(mutex_);
		assertNotAbortedL();
	}

	int err = ready_.timedwait(deadline_);
	if (err != 0) {
		if (err == ETIMEDOUT) {
			Erref lags = new Errors(true);
			{
				pw::lockmutex lm(mutex_); // reading the list must be protected
				for (TrieadUpdMap::iterator it = threads_.begin(); it != threads_.end(); ++it) {
					Triead *t = it->second->t_;
					if (t == NULL) {
						lags->appendMsg(true, it->first + ": not defined");
					} else if (!t->isConstructed()) {
						lags->appendMsg(true, it->first + ": not constructed");
					} else if (!t->isReady()) {
						lags->appendMsg(true, it->first + ": not ready");
					}
				}
			}
			Erref err = new Errors(strprintf(
				"Application '%s' did not initialize within the deadline.\nThe lagging threads are:", name_.c_str()),
				lags);
			throw Exception(err, true);
		} else  {
			throw Exception::fTrace("Internal error: condvar wait for all-ready in application '%s' failed, errno=%d: %s.", 
				name_.c_str(), err, strerror(err));
		}
	}

	{
		pw::lockmutex lm(mutex_);
		assertNotAbortedL();
	}
}

// The way the threads and nexuses are interconnected is very inconvenient
// for finding the loops, so it's converted to an intermediate representation first.

struct NxTr: public Starget
{
	// a graph node representing an edge or a thread
	NxTr(Triead *tr):
		tr_(tr),
		nx_(NULL),
		ninc_(0),
		nextlink_(0)
	{ }

	NxTr(Nexus *nx):
		tr_(NULL),
		nx_(nx),
		ninc_(0),
		nextlink_(0)
	{ }

	NxTr(const NxTr &nxtr):
		tr_(nxtr.tr_),
		nx_(nxtr.nx_),
		ninc_(0), // a fresh copied node has no links
		nextlink_(0)
	{ }

	void addLink(NxTr *target)
	{
		links_.push_back(target);
		target->ninc_++;
	}

	string printName() const
	{
		if (nx_ != NULL)
			return strprintf("nexus '%s/%s'", nx_->getTrieadName().c_str(), nx_->getName().c_str());
		else
			return strprintf("thread '%s'", tr_->getName().c_str());
	}

	Triead *tr_; // if it's a thread
	Nexus *nx_; // if it's a nexus
	int ninc_; // number of incoming connections
	typedef list<NxTr *> List;
	List links_; // links following the model topology
};
struct Graph
{
	typedef map<void *, Autoref<NxTr> > Map;

	NxTr *addTriead(Triead *tr)
	{
		Map::iterator it = m_.find(tr);
		if (it == m_.end())
			return m_[tr] = new NxTr(tr);
		else
			return m_->second;
	}
	NxTr *addNexus(Nexus *nx)
	{
		Map::iterator it = m_.find(nx);
		if (it == m_.end())
			return m_[nx] = new NxTr(nx);
		else
			return m_->second;
	}

	// this one is for copying graphs
	NxTr *addCopy(NxTr *nxtr)
	{
		Map::iterator it = m_.find(nxtr);
		if (it == m_.end())
			return m_[nxtr] = new NxTr(nxtr);
		else
			return m_->second;
	}

	Map m_;
};

void App::checkLoopsL() const
{
	Graph gdown, gup; // separate graphs for direct and reverse nexuses
	Triead::FacetMap nmap;
	NxTr *tnode, *nnode;

	// first build the graphs, separately for the downwards and upwards links
	for (TrieadUpdMap::const_iterator it = threads_.begin(); it != threads_.end(); ++it) {
		Triead *t = it->second;

		t->facets(nmap);
		for (Triead::FacetMap::iterator jt = nmap.begin(); jt != nmap.end(); ++jt) {
			Facet *fa = jt->second;
			if (fa->isReverse()) {
				tnode = gup.addTriead(t);
				nnode = gup.addNexus(fa->nexus());
			} else {
				tnode = gdown.addTriead(t); 
				nnode = gdown.addNexus(fa->nexus());
			}
			// XXX is it better to create graphs in opposite direction?
			if (fa->isWriter()) {
				tnode->addLink(nnode);
			} else {
				nnode->addLink(tnode);
			}
		}
	}
	checkGraphL(gdown, "direct");
	checkGraphL(gup, "reverse");
}

void App::checkGraphL(Graph &g, const char *direction)
{
	typedef list<NxTr *> Nlist;
	Nlist todo; // list of starting-point nodes

	reduceGraphL(g);

	// now whatever links left represent the loops and any twigs coming from them;
	// it would be nice to get rid of the twigs by doing the same traversal 
	// backwards but there are no backwards links;
	// so create a backwards copy of the graph (skipping the nodes that
	// have become disconnected)
	Graph backg;
	for (Map::iterator it = g.m_.begin(); it != g.m_.end(); ++it) {
		NxTr *node = it->second;
		if (node->links_.empty())
			continue;
		NxTr *ncopy = backg.addCopy(node);
		for (NxTr::List::iterator jt = node->links_.begin(); jt != node->links_.end(); ++jt) {
			backg.addCopy(jt->second)->addLink(ncopy);
		}
	}

	reduceGraphL(backg);

	// whatever is left now will contain the loops in it;
	// so just print one loop by always following the first link and always starting
	// from a thread
	for (Map::iterator it = backg.m_.begin(); it != backg.m_.end(); ++it) {
		NxTr *node = it->second;
		if (node->ninc_ != 0 && node->tr_ != NULL) {
			// found a loop, print it from this point
			Erref eloop = new Errors;
			eloop->appendMsg(true, node->printName());
			for (NxTr *cur = node->links_.front(); cur != node; cur = cur->links_.front())
				eloop->appendMsg(true, cur->printName());
			throw Exception::fTrace(eloop, "In application '%s' detected an illegal %s loop:",
				name_.c_str(), direction);
		}
	}
}

// reduce the graph by removing all the links going from the start points
void App::reduceGraphL(Graph &g)
{
	// The graph is a general tree, so there may be many starting points.
	// As we traverse the graph, more untraversed starting points will appear.
	// We traverse until we run out of starting points.
	// The starting points are found by the condition ninc_==0.
	// As the links are traversed, they get deleted.
	// If after traversing from all the starting points there still are
	// untraversed edges, it means that the loops are present.
	for (Map::iterator it = g.m_.begin(); it != g.m_.end(); ++it) {
		NxTr *node = it->second;
		if (!node->links_.empty() && node->ninc_ == 0)
			todo.push_back(node);
	}

	// now traverse
	while (!todo.empty()) {
		NxTr *cur = todo.front();
		NxTr *next = cur->links_.front();
		cur->links_.pop_front();
		if (cur->links_.empty())
			todo.pop_front(); // that was the last link from it, don't return there
		
		// now follow until the path comes to a join
		while (1) {
			cur = next;
			// decrement because an incoming connection has just been consumed
			if (--cur->ninc_ != 0)
				break; // found a join
			if (cur->links_.empty())
				break; // found an endpoint

			next = cur->links_.front();
			cur->links_.pop_front();
			if (!cur->links_.empty())
				todo.push_back(cur); // more links from it, come back to it later
		}
	}
}

}; // TRICEPS_NS

