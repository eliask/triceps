#
# This file is a part of Biceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# The wrapper for Table.

MODULE = Biceps		PACKAGE = Biceps::Table
###################################################################################

void
DESTROY(WrapTable *self)
	CODE:
		// warn("Table destroyed!");
		delete self;


# The table gets created by Unit::makeTable

# XXX add the rest of methods
