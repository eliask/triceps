//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Triead.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "app/Triead.h"

MODULE = Triceps::Triead		PACKAGE = Triceps::Triead
###################################################################################

int
CLONE_SKIP(...)
	CODE:
		RETVAL = 1;
	OUTPUT:
		RETVAL

void
DESTROY(WrapTriead *self)
	CODE:
		// TrieadOwner *to = self->get();
		// warn("TrieadOwner %s %p wrap %p destroyed!", to->get()->getName().c_str(), to, self);
		delete self;

# The Triead objects don't get constructed from Perl, they can only be
# extracted from the TrieadOwner or App.

# check whether both refs point to the same object
int
same(WrapTriead *self, WrapTriead *other)
	CODE:
		clearErrMsg();
		Triead *t1 = self->get();
		Triead *t2 = other->get();
		RETVAL = (t1 == t2);
	OUTPUT:
		RETVAL

char *
getName(WrapTriead *self)
	CODE:
		clearErrMsg();
		Triead *t = self->get();
		RETVAL = (char *)t->getName().c_str();
	OUTPUT:
		RETVAL

char *
fragment(WrapTriead *self)
	CODE:
		clearErrMsg();
		Triead *t = self->get();
		RETVAL = (char *)t->fragment().c_str();
	OUTPUT:
		RETVAL

int
isConstructed(WrapTriead *self)
	CODE:
		clearErrMsg();
		Triead *t = self->get();
		RETVAL = t->isConstructed();
	OUTPUT:
		RETVAL

int
isReady(WrapTriead *self)
	CODE:
		clearErrMsg();
		Triead *t = self->get();
		RETVAL = t->isReady();
	OUTPUT:
		RETVAL

int
isDead(WrapTriead *self)
	CODE:
		clearErrMsg();
		Triead *t = self->get();
		RETVAL = t->isDead();
	OUTPUT:
		RETVAL

int
isInputOnly(WrapTriead *self)
	CODE:
		clearErrMsg();
		Triead *t = self->get();
		RETVAL = t->isInputOnly();
	OUTPUT:
		RETVAL

# XXX add Nexus methods
# XXX test all methods
