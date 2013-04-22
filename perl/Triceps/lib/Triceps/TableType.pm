#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Perl methods for the TableType class.

package Triceps::TableType;

our $VERSION = 'v1.0.1';

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

# Find an index type and its key fields by a path of index names leading from the root.
# The keys include all the key fields from all the indexes in the path, in the order
# they were defined.
# @param self - the TableType object
# @param idxName, ... - array of names
# @return - the array of (found index type, keys...)
# If not found, confesses.
sub findIndexKeyPath # (self, idxName, ...)
{
	my $myname = "Triceps::TableType::findIndexKeyPath";
	my $self = shift;

	confess("$myname: idxPath must be an array of non-zero length, table type is:\n" . $self->print() . " ")
		unless ($#_ >= 0);
	my $cur = $self; # table type is the root of the tree
	my $progress = '';
	my %seenkeys;
	my @keys;
	foreach my $p (@_) {
		$progress .= $p;
		$cur = $cur->findSubIndex($p) 
			or confess("$myname: unable to find the index type at path '$progress', table type is:\n" . $self->print() . " ");
		my @pkey = $cur->getKey();
		confess("$myname: the index type at path '$progress' does not have a key, table type is:\n" . $self->print() . " ")
			unless ($#pkey >= 0);
		foreach my $k (@pkey) {
			confess("$myname: the path '$progress' involves the key field '$k' twice, table type is:\n" . $self->print() . " ")
				if (exists $seenkeys{$k});
			$seenkeys{$k} = 1;
		}
		push @keys, @pkey;
		$progress .= '.';
	}
	return ($cur, @keys);
}

# Copy a table type by extracting only a subsef of indexes,
# without any aggregators. This is generally used for exporting the
# table types to the other threads, supplying barely enough to keep
# the correct structure in the copied table but without any extra
# elements that the local table might have for the side computations.
#
# The path to the first leaf index is included by default.
# It is usually enough, but more indexes can be included for the
# special cases.
#
# @param @paths - list of paths to include into the copy; each path
#        is a reference to an array containing the path; all indexes
#        in the paths will be copied; 
#        a special case is when the value is not an array reference
#        but a string "NO_FIRST_LEAF": it will prevent the default
#        first leaf from being included;
#        the copying will be done in the order it is specified in the
#        arguments, so with "NO_FIRST_LEAF" the first index specified
#        will become the first leaf and thus the default index.
#        The special syntax is supported for the last element in the path:
#            "-" - copy the path to the first leaf from this level down
sub copyFundamental # ($self, @paths)
{
	my $myname = "Triceps::TableType::copyFundamental";
	my $self = shift;
	my @extra;
	my $nofirst = 0;

	while ($#_ >= 0) {
		my $p = shift;
		if ($p eq "NO_FIRST_LEAF") {
			$nofirst = 1;
		} elsif (ref($p) ne "ARRAY") {
			confess "$myname: the arguments must be either references to arrays of path strings or 'NO_FIRST_LEAF', got '$p'";
		} else {
			push @extra, $p;
		}
	}

	if (!$nofirst) {
		# The implicit first leaf amounts to prepending this.
		unshift @extra, [ "-" ];
	}

	my $newtt = Triceps::TableType->new($self->getRowType());

	foreach my $p (@extra) {
		my $curold = $self;
		my $curnew = $newtt;

		my $progress = '';
		my $toleaf = 0;
		foreach my $n (@$p) {
			confess("$myname: the '-' may occur only at the end of the path, got '" . join('.', @$p) . "'")
				if ($toleaf);
			if ($n eq "-") {
				$toleaf = 1;
				while (1) {
					my @allsub = $curold->getSubIndexes();
					last if ($#allsub < 1);

					$progress .= $allsub[0];
					my $nextnew = (eval { $curnew->findSubIndex($allsub[0]) }
						or $curnew->addSubIndex($allsub[0], $allsub[1]->flatCopy()) ->findSubIndex($allsub[0]));
					$progress .= '.';
					$curold = $allsub[1];
					$curnew = $nextnew;
				}
			} else {
				$progress .= $n;
				my $nextold = eval { $curold->findSubIndex($n) }
					or confess("$myname: unable to find the index type at path '$progress', table type is:\n" . $self->print() . " ");
				my $nextnew = (eval { $curnew->findSubIndex($n) }
					or $curnew->addSubIndex($n, $nextold->flatCopy())->findSubIndex($n));
				$progress .= '.';
				$curold = $nextold;
				$curnew = $nextnew;
			}
		}
	}

	return $newtt;
}

1;
