#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# A simple auto-generated aggregator.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 1 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#########################
# The aggregator generation class
#

package Triceps::SimpleAggregator;
use Carp;

use strict;

# the definition of aggregation functions
# in format:
#    funcName => {
#        featureName => featureValue, ...
#    }
our $FUNCTIONS = {
	first => {
		result => '$%argfirst',
	},
	last => {
		result => '$%arglast',
	},
	count_star => {
		argcount => 0,
		result => '$%groupsize',
	},
	count => {
		vars => { count => 0 },
		step => '{ $%count++; } if (defined $%argiter);',
		result => '$%count',
	},
	sum => {
		vars => { sum => 'undef' },
		step => '$%sum += $%argiter;',
		result => '$%sum',
	},
	max => {
		vars => { max => 'undef' },
		step => '{ $%max = $%argiter; } if (!defined $%max || $%argiter > $%max);',
		result => '$%max',
	},
	avg => {
		vars => { sum => 0, count => 0 },
		step => '{ $%sum += $%argiter; $%count++; } if (defined $%argiter);',
		result => '($%count == 0? undef : $%sum / $%count)',
	},
	avg_perl => {
		vars => { sum => 0 },
		step => '$%sum += $%argiter;',
		result => '$%sum / $%groupsize',
	},
};

# Make an aggregator and add it to a table type.
# The arguments are passed in option form, name-value pairs.
# Note: no $class argument!!!
# Options:
#   tabType (TableType) - table type on which to add the aggrgeator
#   name (string) - aggregator name
#   idxPath (reference to array of strings) - path of index type names to
#       the one where the aggregator is to be added
#   result (reference to an array of result field definitions) - repeating groups
#       fieldName => type, function, function_argument
# @return - the same TableType, with added aggregator, or die
sub make # (optName => optValue, ...)
{
	my $opts = {}; # the parsed options
	my $myname = "Triceps::SimpleAggregator::make";
	
	&Triceps::Opt::parse("Triceps::SimpleAggregator", $opts, {
			tabType => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::TableType") } ],
			name => [ undef, \&Triceps::Opt::ck_mandatory ],
			idxPath => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			result => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
		}, @_);

	# find the index type, on which to build the aggregator
	my $idx;
	{
		my @path = @{$opts->{idxPath}};
		confess "$myname: idxPath must be an array of non-zero length"
			unless ($#path >= 0);
		my $cur = $opts->{tabType}; # the root of the tree
		my $progress = '';
		foreach my $p (@path) {
			$cur = $cur->findSubIndex($p) 
				or confess("$myname: unable to find the index type at path '$progress', table type is:\n" . $opts->{tabType}->print() . " ");
			$progress .= '.' . $p;
		}
		$idx = $cur;
	}
	

	# check the result definition and build the result row type and code snippets for the computation
	my $rtRes;
	my $needIter = 0; # flag: some of the functions require iteration
	my $needfirst = 0; # the result needs the first row of the group
	my $needlast = 0; # the result needs the last row of the group
	my $codeInit = ''; # code for function initialization
	my $codeStep = ''; # code for iteration
	my $codeResult = ''; # code to compute the intermediate values for the result
	my $codeBuild = ''; # code to build the result row
	my @compArgs; # the field functions are passed as args to the computation
	{
		my $grpstep = 4; # definition grouped by 4 items per result field
		my @resopt = @{$opts->{result}};
		my @rtdefRes; # field definition for the result
		my $id = 0; # numeric id of the field

		while ($#resopt >= 0) {
			confess "$myname: the values in the result definition must go in groups of 4"
				unless ($#resopt >= 3);
			my $fld = shift @resopt;
			my $type = shift @resopt;
			my $func = shift @resopt;
			my $funcarg = shift @resopt;

			confess("$myname: the result field name must be a string, got a " . ref($fld) . " ")
				unless (ref($fld) ne '');
			confess("$myname: the result field type must be a string, got a " . ref($type) . " for field '$fld'")
				unless (ref($type) ne '');
			confess("$myname: the result field function must be a string, got a " . ref($func) . " for field '$fld'")
				unless (ref($func) ne '');

			my $funcDef = $FUNCTIONS->{$func}
				or confess("$myname: function '" . $func . "' is unknown");

			my $argCount = $funcDef->{argcount}; 
			$argCount = 1 # 1 is the default value
				unless defined($argCount);
			confess("$myname: in field '$fld' function '$funcDef' requires an argument computation that must be a Perl sub reference")
				unless ($argCount == 0 || ref $funcarg eq 'CODE');
			confess("$myname: in field '$fld' function '$funcDef' requires no argument, use undef as a placeholder")
				unless ($argCount != 0 || !defined $funcarg);

			push(@rtdefRes, $fld, $type);

			push(@compArgs, $funcarg)
				if (defined $funcarg);

			# add to the code snippets
			$needIter = 1 if (defined $funcDef->{step});

			### initialization
			my $vars = $funcDef->{vars};
			if (defined $vars) {
				foreach my $v (keys %$vars) {
					# the variable names are given a unique prefix;
					# the initialization values are constants, no substitutions
					$codeInit .= "  my \$v${id}_${v} = " . $vars->{$v} . ";\n";
				}
			} else {
				$vars = { }; # a dummy
			}

			### iteration
			my $step = $funcDef->{step};
			if (defined $step) {
				$codeStep .= "  # for $fld=$func\n";
				if (defined $funcarg) {
					# compute the function argument from the current row
					$codeStep .= "    my \$a${id} = \$args[" . $#compArgs ."](\$row);\n";
				}
				# substitute the variables in $step
				$step =~ s/\$\%(\w+)/&replaceStep($1, $func, $vars, $id, $argCount)/ge;
				$codeStep .= "  { $step; }\n";
			}

			### result building
			my $result = $funcDef->{result};
			confess "Triceps::SimpleAggregator: internal error in definition of aggregation function '$func', missing result computation"
				unless (defined $result);
			# substitute the variables in $result
			if ($result =~ /\$\%argfirst/) {
				$needfirst = 1;
				$codeResult .= "  my \$f${id} = \$args[" . $#compArgs ."](\$rowFirst);\n";
			}
			if ($result =~ /\$\%arglast/) {
				$needlast = 1;
				$codeResult .= "  my \$l${id} = \$args[" . $#compArgs ."](\$rowLast);\n";
			}
			$result =~ s/\$\%(\w+)/&replaceResult($1, $func, $vars, $id, $argCount)/ge;
			$codeBuild .= "    ($result), # $fld\n";

			$id++;
		}
		$rtRes = Triceps::RowType->new(@rtdefRes)
			or confess "$myname: invalid result row type definition: $!";
	}

	# build the computation function
	my $compText = "sub {\n";
	$compText .= "  use strict;\n";
	$compText .= "  my (\$table, \$context, \$aggop, \$opcode, \$rh, \$state, \@args) = \@_;\n";
	$compText .= "  return if (\$context->groupSize()==0 || \$opcode == &Triceps::OP_NOP);\n";
	$compText .= $codeInit;
	if ($needIter) {
		$compText .= "  for (my \$rhi = \$context->begin(); !\$rhi->isNull(); \$rhi = \$context->next(\$rhi)) {\n";
		$compText .= "    my \$row = \$rhi->getRow();\n";
		$compText .= $codeStep;
		$compText .= "  }\n";
	}
	if ($needfirst) {
		$compText .= "  my \$rowFirst = \$context->begin()->getRow();\n";
	}
	if ($needlast) {
		$compText .= "  my \$rowLast = \$context->last()->getRow();\n";
	}
	$compText .= $codeResult;
	$compText .= "  \$context->makeArraySend(\$opcode,\n";
	$compText .= $codeBuild;
	$compText .= "  )\n";
	$compText .= "}\n";

}

# For an aggregation function's step macro, replace a macro variable reference
# with the actual variable.
# @param varname - variable to replace
# @param func - function name, for error messages
# @param vars - definitions of the function's vars
# @param id - the unique id of this field
# @param argCount - the argument count declared by the function
sub replaceStep # ($varname, $func, $vars, $id, $argCount)
{
	my ($varname, $func, $vars, $id, $argCount) = @_;

	if ($varname eq 'argiter') {
		confess "Triceps::SimpleAggregator: internal error in definition of aggregation function '$func', step computation refers to 'argiter' but the function declares no arguments"
			unless ($argCount > 0);
		return "\$a${id}";
	} elsif ($varname eq 'niter') {
		return "\$npos";
	} elsif ($varname eq 'groupsize') {
		return "\$context->groupSize()";
	} elsif (exists $vars->{$varname}) {
		return "\$v${id}_${varname}";
	} else {
		confess "Triceps::SimpleAggregator: internal error in definition of aggregation function '$func', step computation refers to an unknown variable '$varname'"
	}
}

# For an aggregation function's result macro, replace a macro variable reference
# with the actual variable.
# @param varname - variable to replace
# @param func - function name, for error messages
# @param vars - definitions of the function's vars
# @param id - the unique id of this field
# @param argCount - the argument count declared by the function
sub replaceResult # ($varname, $func, $vars, $id, $argCount)
{
	my ($varname, $func, $vars, $id, $argCount) = @_;

	if ($varname eq 'argfirst') {
		confess "Triceps::SimpleAggregator: internal error in definition of aggregation function '$func', result computation refers to '$varname' but the function declares no arguments"
			unless ($argCount > 0);
		return "\$f${id}";
	} elsif ($varname eq 'arglast') {
		confess "Triceps::SimpleAggregator: internal error in definition of aggregation function '$func', result computation refers to '$varname' but the function declares no arguments"
			unless ($argCount > 0);
		return "\$l${id}";
	} elsif ($varname eq 'groupsize') {
		return "\$context->groupSize()";
	} elsif (exists $vars->{$varname}) {
		return "\$v${id}_${varname}";
	} else {
		confess "Triceps::SimpleAggregator: internal error in definition of aggregation function '$func', result computation refers to an unknown variable '$varname'"
	}
}

package main;
