#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# A simple way to generate the aggregators like in SQL.

package Triceps::SimpleAggregator;
use Carp;

use strict;

# Right now the aggregation functions work in a fairly dumb way,
# never additive.

# Should normally not be accessed from outside the package.
# The definition of built-in aggregation functions
# in format:
#    funcName => {
#        featureName => featureValue, ...
#    }
# The user-defined aggregation functions use the same format.
#
# The features are:
#  argcount (optional) - count of arguments to the function, defaults to 1,
#      currently only supports 0 and 1
#  vars (optional) - define the variables used to store the intermediate result
#      as a ref to hash { varName => initializationConstantValue, ... }
#  step (optional) - define the code snippet for one step of the iteration.
#      It should be a complete statement or multiple statements. They will
#      be wrapped in an individual block. They can refer to the special variables:
#        $%argiter - function argument from the current iterated row
#        $%niter - sequential number of the current iterated row (starting from 0)
#        $%groupsize - size of the group being aggregated
#        other $%... - a variable defined in vars
#  result - define the code snippet to compute the result of the function.
#      It must be an expression, not a statement. It can refer to the special variables:
#        $%argfirst - function argument from the first row of the group
#        $%arglast - function argument from the last row of the group
#        $%groupsize - size of the group being aggregated
#        other $%... - a variable defined in vars
#  
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
		step => '$%count++ if (defined $%argiter);',
		result => '$%count',
	},
	sum => {
		vars => { sum => 0 },
		step => '$%sum += $%argiter;',
		result => '$%sum',
	},
	max => {
		vars => { max => 'undef' },
		step => '$%max = $%argiter if (!defined $%max || $%argiter > $%max);',
		result => '$%max',
	},
	min => {
		vars => { min => 'undef' },
		step => '$%min = $%argiter if (!defined $%min || $%argiter < $%min);',
		result => '$%min',
	},
	avg => {
		vars => { sum => 0, count => 0 },
		step => 'if (defined $%argiter) { $%sum += $%argiter; $%count++; }',
		result => '($%count == 0? undef : $%sum / $%count)',
	},
	avg_perl => { # Perl-like treat the NULLs as 0s
		vars => { sum => 0 },
		step => '$%sum += $%argiter;',
		result => '$%sum / $%groupsize',
	},
	nth_simple => { # inefficient, need proper multi-args for better efficiency
		vars => { n => 'undef', tmp => 'undef', val => 'undef' },
		step => '($%n, $%tmp) = @$%argiter; if ($%n == $%niter) { $%val = $%tmp; }',
		result => '$%val',
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
#   saveRowTypeTo (optional, ref to a scalar) - where to save a copy of the result row type
#   saveInitTo (optional, ref to a scalar) - where to save a copy of the init function
#       source code, the saved value may be undef if the init is not used
#   saveComputeTo (optional, ref to a scalar) - where to save a copy of the compute
#       function source code
# @return - the same TableType, with added aggregator, or die
sub make # (optName => optValue, ...)
{
	my $opts = {}; # the parsed options
	my $myname = "Triceps::SimpleAggregator::make";
	
	&Triceps::Opt::parse("Triceps::SimpleAggregator", $opts, {
			tabType => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "Triceps::TableType") } ],
			name => [ undef, \&Triceps::Opt::ck_mandatory ],
			idxPath => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY", "") } ],
			result => [ undef, sub { &Triceps::Opt::ck_mandatory(@_); &Triceps::Opt::ck_ref(@_, "ARRAY") } ],
			saveRowTypeTo => [ undef, sub { !defined($_[0]) or &Triceps::Opt::ck_refscalar(@_) } ],
			saveInitTo => [ undef, sub { !defined($_[0]) or &Triceps::Opt::ck_refscalar(@_) } ],
			saveComputeTo => [ undef, sub { !defined($_[0]) or &Triceps::Opt::ck_refscalar(@_) } ],
		}, @_);

	# reset the saved source code
	${$opts->{saveInitTo}} = undef if (defined($opts->{saveInitTo}));
	${$opts->{saveComputeTo}} = undef if (defined($opts->{saveComputeTo}));
	${$opts->{saveRowTypeTo}} = undef if (defined($opts->{saveRowTypeTo}));

	# find the index type, on which to build the aggregator
	my $idx;
	{
		my @path = @{$opts->{idxPath}};
		confess "$myname: idxPath must be an array of non-zero length"
			unless ($#path >= 0);
		my $cur = $opts->{tabType}; # the root of the tree
		my $progress = '';
		foreach my $p (@path) {
			$progress .= $p;
			$cur = $cur->findSubIndex($p) 
				or confess("$myname: unable to find the index type at path '$progress', table type is:\n" . $opts->{tabType}->print() . " ");
			$progress .= '.';
		}
		$idx = $cur;
	}
	confess "$myname: the index type is already initialized, can not add an aggregator on it"
		if ($idx->isInitialized());
	

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
				unless (ref($fld) eq '');
			confess("$myname: the result field type must be a string, got a " . ref($type) . " for field '$fld'")
				unless (ref($type) eq '');
			confess("$myname: the result field function must be a string, got a " . ref($func) . " for field '$fld'")
				unless (ref($func) eq '');

			my $funcDef = $FUNCTIONS->{$func}
				or confess("$myname: function '" . $func . "' is unknown");

			my $argCount = $funcDef->{argcount}; 
			$argCount = 1 # 1 is the default value
				unless defined($argCount);
			confess("$myname: in field '$fld' function '$func' requires an argument computation that must be a Perl sub reference")
				unless ($argCount == 0 || ref $funcarg eq 'CODE');
			confess("$myname: in field '$fld' function '$func' requires no argument, use undef as a placeholder")
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
				$codeStep .= "    # field $fld=$func\n";
				if (defined $funcarg) {
					# compute the function argument from the current row
					$codeStep .= "    my \$a${id} = \$args[" . $#compArgs ."](\$row);\n";
				}
				# substitute the variables in $step
				$step =~ s/\$\%(\w+)/&replaceStep($1, $func, $vars, $id, $argCount)/ge;
				$codeStep .= "    { $step; }\n";
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
	${$opts->{saveRowTypeTo}} = $rtRes if (defined($opts->{saveRowTypeTo}));

	# build the computation function
	my $compText = "sub {\n";
	$compText .= "  use strict;\n";
	$compText .= "  my (\$table, \$context, \$aggop, \$opcode, \$rh, \$state, \@args) = \@_;\n";
	$compText .= "  return if (\$context->groupSize()==0 || \$opcode == &Triceps::OP_NOP);\n";
	$compText .= $codeInit;
	if ($needIter) {
		$compText .= "  my \$npos = 0;\n";
		$compText .= "  for (my \$rhi = \$context->begin(); !\$rhi->isNull(); \$rhi = \$context->next(\$rhi)) {\n";
		$compText .= "    my \$row = \$rhi->getRow();\n";
		$compText .= $codeStep;
		$compText .= "    \$npos++;\n";
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
	$compText .= "  );\n";
	$compText .= "}\n";

	${$opts->{saveComputeTo}} = $compText if (defined($opts->{saveComputeTo}));

	# compile the computation function
	my $compFun = eval $compText
		or confess "$myname: error in compilation of the aggregation computation:\n  $@\nfunction text:\n$compText ";

	# build and add the aggregator
	my $agg = Triceps::AggregatorType->new($rtRes, $opts->{name}, undef, $compFun, @compArgs)
		or confess "$myname: internal error: failed to build an aggregator type: $! ";

	$idx->setAggregator($agg)
		or confess "$myname: failed to set the aggregator in the index type: $! ";

	return $opts->{tabType};
}

# Should normally not be accessed from outside the package.
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

# Should normally not be accessed from outside the package.
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

1;
