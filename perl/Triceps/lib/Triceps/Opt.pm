#
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# A simple reusable class to parse options.

package Triceps::Opt;
use Carp;

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
#    [0] default value ofr the option (may be undef)
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
		$instance->{$k} = $descr->{k}[0];
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

1;
