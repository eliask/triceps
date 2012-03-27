#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Tests for the barrier.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;
use Carp;

use Test;
BEGIN { plan tests => 1 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use strict;

#########################

package Triceps::Barrier;
use strict;

# A constructor to create a Barrier template.
# The arguments are specified as option name-value pairs:
# unit - the unit where this barrier belongs
# name - the barrier name, used as a prefix for the label names
# data - the dataset description, itself a reference to an array of option name-value pairs
#   (currently only one "data" option may be used, but this will be extended in the future)
#   name - name of the data set, used for its input and output labels
#   rowType - the row type (mutually exclusive with fromLabel)
#   fromLabel - the label that would send the data here, allows to find
#      out the row type and gets the dataset's input automatically chained to that label
#      (mutually exclusive with rowType)
#   key - the key of the data, a reference to array of strings, same as for Hashed index
#
# Confesses on any error.
sub new # ($class, $optName => $optValue, ...)
{
	my $class = shift;
	my $self = {};

	&Triceps::Opt::parse($class, $self, {
		unit => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::Unit") } ],
		name => [ undef, \&Triceps::Opt::ck_mandatory ],
		data => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
	}, @_);
	
	# parse the data element
	my $dataref = $self->{data};
	my $dataset = {};
	&Triceps::Opt::parse("$class data set '" . $dataref->{name} . "'", $dataset, {
		name => [ undef, \&Triceps::Opt::ck_mandatory ],
		key => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY", "") } ],
		rowType => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::RowType") } ],
		fromLabel => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::RowLabel") } ],
	}, @$dataref);

	# save the dataset for the future
	$self->{data}{$dataset->{name}} = $dataset;
	# check the options
	confess ("The data set '" . $dataset->{name} . "' must have only one of rowType or fromLabel")
		if (defined $dataset->{rowType} && defined $dataset->{fromLabel});
	confess ("The data set '" . $dataset->{name} . "' must have exactly one of rowType or fromLabel")
		if (!defined $dataset->{rowType} && !defined $dataset->{fromLabel});
	my $lbFrom = $dataset->{fromLabel};
	if (defined $lbFrom) {
		confess ("The unit of the Barrier and the unit of its data set '" . $dataset->{name} . "' must be the same")
			unless ($self->{unit}->same($lbFrom->getUnit()));
		$dataset->{rowType} = $lbFrom->getType();
	}

	# create the tables
	$dataset->{tt} = Triceps::TableType->new($dataset->{rowType})
		->addSubIndex("primary", 
			Triceps::Index->newHashed(key => $dataset->{key})
		);
	$dataset->{tt}->initialize() 
		or confess ("Barrier table type creation error for dataset '" . $dataset->{name} . "':\n$! ");

	$dataset->{tbInsert} = $self->{unit}->makeTable($dataset->{tt}, "EM_CALL", $self->{name} . "." . $dataset->{name} . ".tbInsert")
		or confess ("Barrier internal error: insert table creation for dataset '" . $dataset->{name} . "':\n$! ");
	$dataset->{tbDelete} = $self->{unit}->makeTable($dataset->{tt}, "EM_CALL", $self->{name} . "." . $dataset->{name} . ".tbInsert")
		or confess ("Barrier internal error: delete table creation for dataset '" . $dataset->{name} . "':\n$! ");

	# create the labels
	$dataset->{lbIn} = $self->{unit}->makeLabel($dataset->{rowType}, $self->{name} . "." . $dataset->{name} . ".lbIn", 
		undef, \&handleInput, $self, $dataset)
			or confess ("Barrier internal error: input label creation for dataset '" . $dataset->{name} . "':\n$! ");
	$dataset->{lbOut} = $self->{unit}->makeDummyLabel($dataset->{rowType}, $self->{name} . "." . $dataset->{name} . ".lbOut")
		or confess ("Barrier internal error: output label creation for dataset '" . $dataset->{name} . "':\n$! ");
			
	# chain the input label, if any
	if (defined $lbFrom) {
		$lbFrom->chain($dataset->{lbIn})
			or confess ("Barrier internal error: input label chaining for dataset '" . $dataset->{name} . "' to '" . $lbFrom->getName() . "' failed:\n$! ");
	}

	bless $self, $class;
	return $self;
}

# handle one incoming row on a dataset's input label
sub handleInput # ($label, $rop, $self, $dataset)
{
	my $label = shift;
	my $rop = shift;
	my $self = shift;
	my $dataset = shift;

	if ($rop->isInsert()) {
		# Simply add to the insert table: the effect is the same, independently of
		# whether the row was previously deleted or not. This also handles correctly
		# multiple inserts without a delete between them, even though this kind of
		# input is not really expected.
		$dataset->{tbInsert}->insert($rop->getRow())
			or confess ("Barrier " . $self->{name} . " internal error: dataset '" . $dataset->{name} . "' failed an insert-table-insert:\n$! ");
	} elsif($rop->isDelete()) {
		# If there was a row in the insert table, delete that row (undoing the previous insert).
		# Otherwise it means that there was no previous insert seen in this round, so this must be a
		# deletion of a row inserted in the previous round, so insert it into the delete table.
		if (! $dataset->{tbInsert}->deleteRow($rop->getRow())) {
			confess ("Barrier " . $self->{name} . " internal error: dataset '" . $dataset->{name} . "' failed an insert-table-delete:\n$! ")
				if ($! ne "");
			$dataset->{tbDelete}->insert($rop->getRow())
				or confess ("Barrier " . $self->{name} . " internal error: dataset '" . $dataset->{name} . "' failed a delete-table-insert:\n$! ");
		}
	}
}

# Unlatch and flush the collected data, then latch again.
sub flush # ($self)
{
	my $self = shift;
	my $unit = $self->{unit};
	my $OP_INSERT = &Triceps::OP_INSERT;
	my $OP_DELETE = &Triceps::OP_DELETE;
	foreach my $dataset (values %{$self->{data}}) {
		my $tbIns = $dataset->{tbInsert};
		my $tbDel = $dataset->{tbDelete};
		my $lbOut = $dataset->{lbOut};
		my $next;
		# send the deletes always before the inserts
		for (my $rh = $tbDel->begin(); !$rh->isNull(); $rh = $next) {
			$next = $rh->next(); # advance the irerator before removing
			$tbDel->remove($rh);
			$unit->call($lbOut->makeRowop($OP_DELETE, $rh->getRow()));
		}
		for (my $rh = $tbIns->begin(); !$rh->isNull(); $rh = $next) {
			$next = $rh->next(); # advance the irerator before removing
			$tbIns->remove($rh);
			$unit->call($lbOut->makeRowop($OP_INSERT, $rh->getRow()));
		}
	}
}

# TODO In the future may also have separate calls for latching and unlatching.

package main;

#########################

# XXX test it!
