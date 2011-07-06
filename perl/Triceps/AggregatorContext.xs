//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The context for an aggregator handler call.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"
#include "WrapAggregatorContext.h"

// The idea here is to combine multiple C++ structures that are used only in
// an aggregator handler call into a insgle Perl object, thus simplifying the
// API for the Perl aggregators.

WrapMagic magicWrapAggregatorContext = { "AggCtx" };

MODULE = Triceps::AggregatorContext		PACKAGE = Triceps::AggregatorContext
###################################################################################

void
DESTROY(WrapAggregatorContext *self)
	CODE:
		// warn("AggregatorContext destroyed!");
		delete self;

