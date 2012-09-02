#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Perl methods for the Rowop class.

package Triceps::Rowop;

our $VERSION = 'v1.0.1';

# convert a rowop to a printable string, with name-value pairs
# (printP stands for "print in Perl")
package  Triceps::Rowop;
sub printP # ($self)
{
	my $self = shift;
	return $self->getLabel()->getName() . " " . Triceps::opcodeString($self->getOpcode()) . " " . $self->getRow()->printP();
}

1;
