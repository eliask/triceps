#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Perl hepler methods for the App.

package Triceps::App;

our $VERSION = 'v1.0.1';

use Carp;
use strict;

# These variables are used by build(). The user can access them too.
# Since all the variables are local to a thread, these are too.
# And they must not be used outside of build().
our $app; # the App object being built
our $name; # the name of the App being built
our $global; # the "global" thread owner

# This provides an easy outer shell for building an App.
# It creates a temporary service thread "global" that holds the
# app until all the first-level threads are defined. It can
# also be used to export the nexuses with row types and even labels.
sub build($&) { # ($appname, &builder)
	$name = shift; # package var!
	my $code = shift;
	$app = &make($name);
	$global = Triceps::TrieadOwner->new(undef, undef, $app, "global", "");
	eval { &$code() };
	$global->abort($@) if ($@);
	$global->markDead();
	eval { $app->harvester(); };
	my $err = $@;
	undef $app; 
	undef $name; 
	undef $global;
	die $err if ($err);
}

# The options are the same as for TrieadOwner::makeNexus,
# except that 
#   import => "none"
# is always implicitly added. And the facet is never returned.
sub globalNexus { # (@opts)
	$global->makeNexus(@_, import => "none");
	return undef;
}

1;
