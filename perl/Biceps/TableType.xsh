#
# This file is a part of Biceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The wrapper for TableType.

MODULE = Biceps		PACKAGE = Biceps::TableType
###################################################################################

void
DESTROY(WrapTableType *self)
	CODE:
		// warn("TableType destroyed!");
		delete self;

