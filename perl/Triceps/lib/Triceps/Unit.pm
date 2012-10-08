#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Perl methods for the Unit class.

package Triceps::Unit;

our $VERSION = 'v1.0.1';

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
	my $res = $self->call($rowop) or Carp::confess "$!";
	return $res;
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
	my $res = $self->call($rowop) or Carp::confess "$!";
	return $res;
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
	my $res = $self->schedule($rowop) or Carp::confess "$!";
	return $res;
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
	my $res = $self->schedule($rowop) or Carp::confess "$!";
	return $res;
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
	my $res = $self->loopAt($mark, $rowop) or Carp::confess "$!";
	return $res;
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
	my $res = $self->loopAt($mark, $rowop) or Carp::confess "$!";
	return $res;
}

# Create a whole combination for the start of the loop:
#  1. The first label inside the actual loop, that runs on
#    every iteration. It gets the clearSub and execSub to execute in it.
#    The user code doesn't need to bother about setting
#    the frame mark, it's set in the wrapper.
#  2. The frame mark.
#
# Confesses on any error.
#
# @param rt - row type for the looping rows
# @param name - base name for the labels and the mark.
#     The names are created with suffixes as:
#     1. First label in the loop: .next
#     2. The frame mark: .mark
# @param clearSub - clearing function for .next
# @param execSub - handler function for .next
# @param args - args for .next
# @returns - a pair of
#     ($next_label, $frame_mark)
sub makeLoopHead # ($self, $rt, $name, $clearSub, $execSub, @args)
{
	my ($self, $rt, $name, $clear, $exec, @args) = @_;

	my $mark = Triceps::FrameMark->new($name . ".mark") or confess "$!";

	my $lbNext = $self->makeLabel($rt, $name . ".next", $clear, sub {
		$self->setMark($mark);
		&$exec(@_);
	}, @args) or confess "$!";

	return ($lbNext, $mark);
}

# Similar to makeLoopHead() but the first label inside the loop
# already exists, so just makes the rest: the
# frame mark and the helper label that will set the mark.
#
# Confesses on any error.
#
# @param name - base name for the labels and the mark.
#     The names are created with suffixes as:
#     1. Wrapper for the first label in the loop: .wrapnext;
#        that should be used with loopAt().
#     2. The frame mark: .mark
# @param lbFirst - the label that starts the loop. Its row type
#     also becomes the row type of the created labels.
# @returns - a triplet of
#     ($next_label, $frame_mark)
sub makeLoopAround # ($self, $name, $lbFirst)
{
	my ($self, $name, $lbFirst) = @_;
	my $rt = $lbFirst->getRowType();

	my $mark = Triceps::FrameMark->new($name . ".mark") or confess "$!";

	my $lbWrapNext = $self->makeLabel($rt, $name . ".wrapnext", undef, sub {
		$self->setMark($mark);
	}) or confess "$!";
	$lbWrapNext->chain($lbFirst) or confess "$!";

	return ($lbWrapNext, $mark);
}

1;
