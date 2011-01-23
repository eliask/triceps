//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Test of Autoref methods, applied on Starget.

#include <utest/Utest.h>

#include <mem/Starget.h>

class tg : public Starget
{
public:
	static int outstanding; // count of outstanding objects

	tg() :
		data_(0)
	{
		++outstanding;
	}

	~tg() 
	{
		--outstanding;
	}

	static Autoref<tg> factory()
	{
		return new tg;
	}

	int data_;
};
int tg::outstanding = 0;

// Now, this is a bit funny, since strprintf() is used inside the etst infrastructure
// too. But if it all works, it should be all good.

UTESTCASE nullref(Utest *utest)
{
	Autoref<tg> p;

	UT_ASSERT(p.isNull());
	UT_ASSERT(p.get() == NULL);
	UT_ASSERT((tg *)p == NULL);
}

UTESTCASE construct(Utest *utest)
{
	UT_ASSERT(tg::outstanding == 0);
	{
		Autoref<tg> p(new tg);
		UT_ASSERT(tg::outstanding == 1);
	}
	UT_ASSERT(tg::outstanding == 0);
}

UTESTCASE factory(Utest *utest)
{
	UT_ASSERT(tg::outstanding == 0);

	Autoref<tg> p;
	UT_ASSERT(p.isNull());
	p = tg::factory();
	UT_ASSERT(tg::outstanding == 1);
	p = NULL;
	UT_ASSERT(tg::outstanding == 0);
}

UTESTCASE assign(Utest *utest)
{
	UT_ASSERT(tg::outstanding == 0);
	Autoref<tg> p2;
	{
		Autoref<tg> p(new tg);
		UT_ASSERT(tg::outstanding == 1);
		p = p;
		UT_ASSERT(tg::outstanding == 1);
		p2 = p;
		UT_ASSERT(tg::outstanding == 1);
		p2 = p;
		UT_ASSERT(tg::outstanding == 1);

		UT_ASSERT(p2->data_ == 0);
		p->data_ = 1;
		UT_ASSERT(p2->data_ == 1);

		p = tg::factory();
		UT_ASSERT(tg::outstanding == 2);
	}
	UT_ASSERT(tg::outstanding == 1);
	p2 = 0;
	UT_ASSERT(tg::outstanding == 0);
}
