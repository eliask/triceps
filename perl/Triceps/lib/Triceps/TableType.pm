#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Perl methods for the TableType class.

package Triceps::TableType;
use Carp;

use strict;

# Find an index type by a path of index names leading from the root.
# @param self - the TableType object
# @param idxName, ... - array of names
# @return - the found index type
# If not found, confesses.
sub findIndexPath # (self, idxName, ...)
{
	my $myname = "Triceps::TableType::findIndexPath";
	my $self = shift;

	confess("$myname: idxPath must be an array of non-zero length, table type is:\n" . $self->print() . " ")
		unless ($#_ >= 0);
	my $cur = $self; # table type is the root of the tree
	my $progress = '';
	foreach my $p (@_) {
		$progress .= $p;
		$cur = $cur->findSubIndex($p) 
			or confess("$myname: unable to find the index type at path '$progress', table type is:\n" . $self->print() . " ");
		$progress .= '.';
	}
	return $cur;
}

1;
