//
// (C) Copyright 2011-2013 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Facet.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "app/Facet.h"

MODULE = Triceps::Facet		PACKAGE = Triceps::Facet
###################################################################################

int
CLONE_SKIP(...)
	CODE:
		RETVAL = 1;
	OUTPUT:
		RETVAL

void
DESTROY(WrapFacet *self)
	CODE:
		// Facet *fa = self->get();
		// warn("Facet %s %p wrap %p destroyed!", fa->getFullName().c_str(), to, self);
		delete self;

# check whether both refs point to the same object
int
same(WrapFacet *self, WrapFacet *other)
	CODE:
		clearErrMsg();
		Facet *fa1 = self->get();
		Facet *fa2 = other->get();
		RETVAL = (fa1 == fa2);
	OUTPUT:
		RETVAL

char *
getShortName(WrapFacet *self)
	CODE:
		clearErrMsg();
		Facet *fa = self->get();
		RETVAL = (char *)fa->getShortName().c_str();
	OUTPUT:
		RETVAL

char *
getFullName(WrapFacet *self)
	CODE:
		clearErrMsg();
		Facet *fa = self->get();
		RETVAL = (char *)fa->getFullName().c_str();
	OUTPUT:
		RETVAL

