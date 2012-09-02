#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# A simple reusable class to parse options.

package Triceps::Opt;

our $VERSION = 'v1.0.1';

use Carp;
use Scalar::Util;

# The idea here is that there may be many classes that take
# arguments in the form optName  => optValue, and it would be
# nice to have a common code that would check them and complain
# on errors.
# There is already a similar code in CPAN, but it's easy to
# reimplement and make more suited for Triceps use, instead of
# doing some wrappers over it.

# Parse a set of options. Die (with stack trace) on errors.
#  @param $class - class name whose options are being parsed, for error messages
#  @param %$instance - reference to a in instance of the class (a hash) where the
#     options will be placed, with the same names
#  @param %$optdescr - reference to a hash with description of supported options
#  @params @opts - passed-through option arguments (name-value pairs)
#
# The option description is formatted as follows: a hash containing array
# refs. The keys of the hash are option names. The value arrays contain:
#    [0] default value of the option (may be undef)
#    [1] checking function reference for the option (see below), or undef
# For example:
#    my $optdef =  {
#        mand => [ undef, \&parseopt::ck_mandatory ],
#        opt => [ 9, undef ],
#    };
sub parse # ($class, %$instance, %$optdescr, @opts)
{
	my $class = shift;
	my $instance = shift;
	my $descr = shift; # ref to hash of optionName => defaultValue
	my ($k, $varr, $v);

	foreach $k (keys %$descr) { # set the defaults
		$v = $descr->{$k}[0];
		#print STDERR "DEBUG set $k=(", $v, ")\n";
		$instance->{$k} = $descr->{$k}[0];
	}

	while ($#_ >= 1) { # pick in pairs
		$k = shift;
		$v = shift;
		Carp::confess "Unknown option '$k' for class '$class'"
			unless exists $descr->{$k};
		$instance->{$k} = $v;
	}
	Carp::confess "Last option '$k' for class '$class' is without a value"
		unless $#_ == -1;

	# now check the values: must go through all the defined options,
	# or the missing mandatory options won't be caught
	foreach $k (keys %$descr) {
		$varr = $descr->{$k}; # value array: ($defval, \&check)
		if (defined $varr->[1]) { # run the check
			&{$varr->[1]}($instance->{$k}, $k, $class, $instance); # will die on error
		}
	}
}

# checking methoods: they share the same signature (with possibly more
# arguments added) and can be called from the user's checking
# The signature is:
# ($optval, $optname, $class, %$instance, ...)
#    @param optval - option value that is being tested
#    @param optname - option name
#    @param class - class name
#    @param instance - object instance where all the options can be found
#    @param ... - possible extra arguments if called not directly by parse()
#          but through other user code that adds them
# If the check fails, the method dies (or confesses).

# check that the option value is not undef
sub ck_mandatory
{
	#print STDERR "\nDEBUG ck_mandatory('" . join("', '", @_) . "')\n";
	my ($optval, $optname, $class, $instance) = @_;
	Carp::confess "Option '$optname' must be specified for class '$class'"
		unless defined $optval;
}

# check that the option value is a reference to a class
# @param refto - class name (or ARRAY or HASH)
# @param reftoref (optional) - if refto is ARRAY or HASH, can be used
#        to specify the type of values in it
sub ck_ref
{
	#print STDERR "\nDEBUG ck_ref('" . join("', '", @_) . "')\n";
	my ($optval, $optname, $class, $instance, $refto, $reftoref) = @_;
	return if !defined $optval; # undefined value is OK
	my $rval = ref $optval;
	Carp::confess "Option '$optname' of class '$class' must be a reference to '$refto', is '$rval'"
		unless ($rval eq $refto || &Scalar::Util::blessed($optval) && $optval->isa($refto));
	if (defined  $reftoref) {
		if ($rval eq "ARRAY") {
			foreach my $v (@$optval) {
				$rval = ref $v;
				Carp::confess "Option '$optname' of class '$class' must be a reference to '$refto' '$reftoref', is '$refto' '$rval'"
					unless ($rval eq $reftoref || &Scalar::Util::blessed($v) && $v->isa($reftoref));
			}
		} elsif ($rval eq "HASH") {
			foreach my $v (values %$optval) {
				$rval = ref $v;
				Carp::confess "Option '$optname' of class '$class' must be a reference to '$refto' '$reftoref', is '$refto' '$rval'"
					unless ($rval eq $reftoref || &Scalar::Util::blessed($v) && $v->isa($reftoref));
			}
		} else {
			Carp::confess "Incorrect arguments, may use the second type only if the first is ARRAY or HASH"
		}
	}
}

# check that the option value is a reference to a scalar
# (for the values to be returned, where the scalar value will be overwritten);
# if it's an input value that really must be a scalar then use ck_ref(@_, 'SCALAR') instead
sub ck_refscalar
{
	#print STDERR "\nDEBUG ck_refscalar('" . join("', '", @_) . "')\n";
	my ($optval, $optname, $class, $instance, $refto, $reftoref) = @_;
	return if !defined $optval; # undefined value is OK
	my $rval = ref $optval;
	# a tricky point: a scalar may contain a reference in it, which is OK since it will be overwritten
	Carp::confess "Option '$optname' of class '$class' must be a reference to a scalar, is '$rval'"
		unless ($rval eq 'SCALAR' || $rval eq 'REF');
}

###########
# Handling ot the typical unit-inputRowType-fromLabel triangle, where
# the fromLabel can replace the other two.
#
# Checks that everything is compatible. If the label is specified
# and the unit is not, then populates the unit.
# On error confesses. On success returns 1.
#
# Strictly speaking, the label doesn't have to be a Label. It can be
# anything with methods getUnit() and getRowType(), for example a Table.
#
# @param caller - the name of the caller function, for error messages
# @param nameUnit - name of the unit option, for messages
# @param refUnit - reference to the unit value
# @param nameRowType - name of the row type option, for messages
# @param refRowType - reference to the row type value
# @param nameLabel - name of the label option, for messages
# @param refLabel - reference to the label value
sub handleUnitTypeLabel($$$$$$$) # ($caller, $nameUnit, \$refUnit, $nameRowType, \$refRowType, $nameLabel, \$refLabel)
{
	my ($caller, $nameUnit, $refUnit, $nameRowType, $refRowType, $nameLabel, $refLabel) = @_;
	
	confess "$caller: must have only one of options $nameRowType or $nameLabel"
		if (defined $$refRowType && defined $$refLabel);
	confess "$caller: must have exactly one of options $nameRowType or $nameLabel"
		if (!defined $$refRowType && !defined $$refLabel);
	if (defined $$refLabel) {
		if (defined $$refUnit) {
			confess("$caller: the label '" . $$refLabel->getName() . "' in option $nameLabel has a mismatched unit ('" 
					. $$refLabel->getUnit()->getName() . "' vs '" . $$refUnit->getName() . "')")
				unless ($$refUnit->same($$refLabel->getUnit()));
		} else {
			$$refUnit = $$refLabel->getUnit();
		}
		$$refRowType = $$refLabel->getRowType();
	}
	confess "$caller: option $nameUnit must be specified"
		unless (defined $$refUnit);

	return 1;
}

###########
# Handling of the mutually exclusive options.
# Checks that no more than one (or exactly one if mandatory != 0) option
# has a value. Confesses on error.
#
# @param caller - the name of the caller function, for error messages
# @param mandatory - flag: if not 0, exactly one of the options must be specified, 
#    otherwise all are optional
# @param optNameN, optValueN - name and actual value of each of the options
# @return - name of the only defined option, or undef if none defined
sub checkMutuallyExclusive # ($caller, $mandatory, $optName1, optValue1, ...)
{
	my $caller = shift;
	my $mandatory = shift;
	my(@names, @values, @used);
	my($n, $v);
	while ($#_ >= 0) {
		$n = shift @_;
		$v = shift @_;
		push @names, $n;
		push @values, $v;
		push @used, $n
			if (defined $v);
	}
	confess("$caller: must have only one of options " . join(" or ", @names) . ", got both " . join(" and ", @used))
		unless ($#used <= 0);
	confess("$caller: must have exactly one of options " . join(" or ", @names) . ", got none of them")
		if ($mandatory && $#used != 0);

	return $used[0];
}

1;
