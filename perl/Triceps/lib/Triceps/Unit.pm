#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Perl methods for the Unit class.

package Triceps::Unit;
use Carp;

# A convenience wrapper that creates the Rowop from
# the field name-value pairs and then calls it.
# Eventually should move to XS for higher efficiency.
# @param label - label to call
# @param opcode - opcode for the rowop
# @param fieldName, fieldValue - pairs defining the data for the row
sub makeHashCall # (self, label, opcode, fieldName => fieldValue, ...)
{
	my $self = shift;
	my $label = shift;
	my $rowop = $label->makeRowopHash(@_) or Carp::confess "$!";
	return $self->call($rowop);
}

# A convenience wrapper that creates the Rowop from
# the field value array and then calls it.
# Eventually should move to XS for higher efficiency.
# @param label - label to call
# @param opcode - opcode for the rowop
# @param fieldValue - values defining the data for the row
sub makeArrayCall # (self, label, opcode, fieldValue, ...)
{
	my $self = shift;
	my $label = shift;
	my $rowop = $label->makeRowopArray(@_) or Carp::confess "$!";
	return $self->call($rowop);
}

# A convenience wrapper that creates the Rowop from
# the field name-value pairs and then schedules it.
# Eventually should move to XS for higher efficiency.
# @param label - label to schedule
# @param opcode - opcode for the rowop
# @param fieldName, fieldValue - pairs defining the data for the row
sub makeHashSchedule # (self, label, opcode, fieldName => fieldValue, ...)
{
	my $self = shift;
	my $label = shift;
	my $rowop = $label->makeRowopHash(@_) or Carp::confess "$!";
	return $self->schedule($rowop);
}

# A convenience wrapper that creates the Rowop from
# the field value array and then schedules it.
# Eventually should move to XS for higher efficiency.
# @param label - label to schedule
# @param opcode - opcode for the rowop
# @param fieldValue - values defining the data for the row
sub makeArraySchedule # (self, label, opcode, fieldValue, ...)
{
	my $self = shift;
	my $label = shift;
	my $rowop = $label->makeRowopArray(@_) or Carp::confess "$!";
	return $self->schedule($rowop);
}

# A convenience wrapper that creates the Rowop from
# the field name-value pairs and then enqueues a loop to it.
# Eventually should move to XS for higher efficiency.
# @param mark - the loop mark
# @param label - label to call
# @param opcode - opcode for the rowop
# @param fieldName, fieldValue - pairs defining the data for the row
sub makeHashLoopAt # (self, mark, label, opcode, fieldName => fieldValue, ...)
{
	my $self = shift;
	my $mark = shift;
	my $label = shift;
	my $rowop = $label->makeRowopHash(@_) or Carp::confess "$!";
	return $self->loopAt($mark, $rowop);
}

# A convenience wrapper that creates the Rowop from
# the field value array and then enqueues a loop to it.
# Eventually should move to XS for higher efficiency.
# @param mark - the loop mark
# @param label - label to call
# @param opcode - opcode for the rowop
# @param fieldValue - values defining the data for the row
sub makeArrayLoopAt # (self, mark, label, opcode, fieldValue, ...)
{
	my $self = shift;
	my $mark = shift;
	my $label = shift;
	my $rowop = $label->makeRowopArray(@_) or Carp::confess "$!";
	return $self->loopAt($mark, $rowop);
}

1;
