#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Template to collapse multiple sequential updates into one.

package Triceps::Collapse;
use Carp;
use strict;

# A constructor to create a Collapse template.
# It collapses multiple changes on each key into at most one delete and one insert,
# matching the final result after all the modifications.
# This allows to skip the intermediate updates, if only the end result is of interest.
#
# The arguments are specified as option name-value pairs:
# unit - the unit where this barrier belongs
# name - the barrier name, used as a prefix for the label names
# data - the dataset description, itself a reference to an array of option name-value pairs
#   (currently only one "data" option may be used, but this will be extended in the future)
#   name - name of the data set, used for its input and output labels, always make it
#      the first option (to get the correct name used in the error messages)
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
	# dataref->[1] is the best guess for the dataset name, in case if the option "name" goes first
	&Triceps::Opt::parse("$class data set (" . $dataref->[1] . ")", $dataset, {
		name => [ undef, \&Triceps::Opt::ck_mandatory ],
		key => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY", "") } ],
		rowType => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::RowType"); } ],
		fromLabel => [ undef, sub { &Triceps::Opt::ck_ref(@_, "Triceps::Label"); } ],
	}, @$dataref);

	# save the dataset for the future
	$self->{datasets}{$dataset->{name}} = $dataset;
	# check the options
	&Triceps::Opt::handleUnitTypeLabel("Triceps::Collapse data set (". $dataset->{name} . ")",
		"unit", \$self->{unit}, "rowType", \$dataset->{rowType}, "fromLabel", \$dataset->{fromLabel});
	my $lbFrom = $dataset->{fromLabel};

	# create the tables
	$dataset->{tt} = Triceps::TableType->new($dataset->{rowType})
		->addSubIndex("primary", 
			Triceps::IndexType->newHashed(key => $dataset->{key})
		);
	$dataset->{tt}->initialize() 
		or confess "Collapse table type creation error for dataset '" . $dataset->{name} . "':\n$! ";

	$dataset->{tbInsert} = $self->{unit}->makeTable($dataset->{tt}, "EM_CALL", $self->{name} . "." . $dataset->{name} . ".tbInsert")
		or confess "Collapse internal error: insert table creation for dataset '" . $dataset->{name} . "':\n$! ";
	$dataset->{tbDelete} = $self->{unit}->makeTable($dataset->{tt}, "EM_CALL", $self->{name} . "." . $dataset->{name} . ".tbInsert")
		or confess "Collapse internal error: delete table creation for dataset '" . $dataset->{name} . "':\n$! ";

	# create the labels
	$dataset->{lbIn} = $self->{unit}->makeLabel($dataset->{rowType}, $self->{name} . "." . $dataset->{name} . ".in", 
		undef, \&_handleInput, $self, $dataset)
			or confess "Collapse internal error: input label creation for dataset '" . $dataset->{name} . "':\n$! ";
	$dataset->{lbOut} = $self->{unit}->makeDummyLabel($dataset->{rowType}, $self->{name} . "." . $dataset->{name} . ".out")
		or confess "Collapse internal error: output label creation for dataset '" . $dataset->{name} . "':\n$! ";
			
	# chain the input label, if any
	if (defined $lbFrom) {
		$lbFrom->chain($dataset->{lbIn})
			or confess "Collapse internal error: input label chaining for dataset '" . $dataset->{name} . "' to '" . $lbFrom->getName() . "' failed:\n$! ";
		delete $dataset->{fromLabel}; # no need to keep the reference any more, avoid a reference cycle
	}

	bless $self, $class;
	return $self;
}

# (protected)
# handle one incoming row on a dataset's input label
sub _handleInput # ($label, $rop, $self, $dataset)
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
		$dataset->{tbInsert}->insert($rop->getRow());
	} elsif($rop->isDelete()) {
		# If there was a row in the insert table, delete that row (undoing the previous insert).
		# Otherwise it means that there was no previous insert seen in this round, so this must be a
		# deletion of a row inserted in the previous round, so insert it into the delete table.
		if (! $dataset->{tbInsert}->deleteRow($rop->getRow())) {
			$dataset->{tbDelete}->insert($rop->getRow());
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
	foreach my $dataset (values %{$self->{datasets}}) {
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

# Get the input label of a dataset.
# Confesses on error.
sub getInputLabel($$) # ($self, $dsetname)
{
	my ($self, $dsetname) = @_;
	confess "Unknown dataset '$dsetname'"
		unless exists $self->{datasets}{$dsetname};
	return $self->{datasets}{$dsetname}{lbIn};
}

# Get the output label of a dataset.
# Confesses on error.
sub getOutputLabel($$) # ($self, $dsetname)
{
	my ($self, $dsetname) = @_;
	confess "Unknown dataset '$dsetname'"
		unless exists $self->{datasets}{$dsetname};
	return $self->{datasets}{$dsetname}{lbOut};
}

# Get the lists of datasets (currently only one).
sub getDatasets($) # ($self)
{
	my $self = shift;
	return keys %{$self->{datasets}};
}

# TODO In the future may also have separate calls for latching and unlatching.

1;
