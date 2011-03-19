//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Wrappers for handling of objects from interpreted languages.

#include <wrap/Wrap.h>

namespace BICEPS_NS {

WrapMagic magicWrapUnit = { "unit" };
WrapMagic magicWrapRowType = { "rowtype" };
WrapMagic WrapRow::classMagic_ = { "rowP" };

}; // BICEPS_NS
