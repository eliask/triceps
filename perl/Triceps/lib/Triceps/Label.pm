#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Perl methods for the Label class.

package Triceps::Label;

our $VERSION = 'v1.0.1';

use Carp;

# A convenience wrapper that creates the Rowop from
# the field name-value pairs, handling the look-up of the
# row type.
# Eventually should move to XS for higher efficiency.
# @param opcode - opcode for the rowop
# @param fieldName, fieldValue - pairs defining the data for the row
sub makeRowopHash # (self, opcode, fieldName => fieldValue, ...)
{
	my $self = shift;
	my $opcode = shift;
	my $row = $self->getType()->makeRowHash(@_) or Carp::confess "$!";
	my $rop = $self->makeRowop($opcode, $row) or Carp::confess "$!";
	return $rop;
}

# A convenience wrapper that creates the Rowop from
# the field value array, handling the look-up of the
# row type.
# Eventually should move to XS for higher efficiency.
# @param opcode - opcode for the rowop
# @param fieldValue - values defining the data for the row
sub makeRowopArray # (self, opcode, fieldValue, ...)
{
	my $self = shift;
	my $opcode = shift;
	my $row = $self->getType()->makeRowArray(@_) or Carp::confess "$!";
	my $rop = $self->makeRowop($opcode, $row) or Carp::confess "$!";
	return $rop;
}

1;
