//
// (C) Copyright 2011-2012 Sergey A. Babkin.
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Wrappers for handling of objects from interpreted languages.

#include <wrap/Wrap.h>

namespace TRICEPS_NS {

WrapMagic magicWrapRowType = { "RowType" };
WrapMagic magicWrapRow = { "RowP" };
WrapMagic magicWrapIndexType = { "IndexT" };
WrapMagic magicWrapTableType = { "TableT" };

WrapMagic magicWrapUnit = { "Unit" };
WrapMagic magicWrapUnitTracer = { "UnitTrc" };
WrapMagic magicWrapUnitClearingTrigger = { "UnClTg" };
WrapMagic magicWrapTray = { "Tray" };
WrapMagic magicWrapLabel = { "Label" };
WrapMagic magicWrapGadget = { "Gadget" };
WrapMagic magicWrapRowop = { "Rowop" };
WrapMagic magicWrapFrameMark = { "FrMark" };
WrapMagic magicWrapFnReturn = { "FnRet" };
WrapMagic magicWrapFnBinding = { "FnBind" };
WrapMagic magicWrapAutoFnBind = { "AuFnBnd" };

WrapMagic magicWrapTable = { "Table" };
WrapMagic magicWrapIndex = { "Index" };
WrapMagic magicWrapRowHandle = { "RowHand" };

}; // TRICEPS_NS
