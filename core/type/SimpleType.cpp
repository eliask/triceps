//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Common subclass for the simple types

#include <type/SimpleType.h>

namespace BICEPS_NS {

Erref SimpleType::getErrors() const
{
	return NULL; // never any errors
}

}; // BICEPS_NS
