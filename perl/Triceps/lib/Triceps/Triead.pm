#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Perl methods for the Row class.

package Triceps::Triead;

our $VERSION = 'v1.0.1';

use Carp;
use threads;

use strict;

# The options for start(). Keeping them in a variable allows the individual
# thread main functions to copy and reuse their definition instead of
# reinventing it.
our @startOpts = (
	app => [ undef, \&Triceps::Opt::ck_mandatory ],
	thread => [ undef, \&Triceps::Opt::ck_mandatory ],
	frag => [ "", undef ],
	main => [ undef, sub { &Triceps::Opt::ck_ref(@_, "CODE") } ],
);

# Start a new Triead.
# Use:
# Triceps::Triead::start(@options);
# 
# All the options are passed through to the main function, even if they are not recognized.
# The recognized options are:
#
# app => $appname
# Name of the app that owns this thread.
#
# thread => $threadname
# Name for this thread.
#
# frag => $fragname
# Name of the fragment (default: "").
#
# main => \&function
# The main function of the thread that will be called with &ll the options
# plus some more:
#     &$func(@opts, owner => $ownerObj )
# owner: the TrieadOwner object constructed for this thread
#
sub start { # (@opts)
	my $myname = "Triceps::Triead::start";
	my $opts = {};

	# the logic works by connecting the output of each table in a
	# LookupJoin of the other table

	&Triceps::Opt::parse($myname, $opts, {
		@startOpts,
		'*' => [],
	}, @_);

	# This avoids the race if we're about to wait for this thread.
	Triceps::App::declareTriead($opts->{app}, $opts->{thread});

	my @args = @_;
	@_ = (); # workaround for threads leaking objects
	threads->create(sub {
		push(@_, "owner",
			Triceps::TrieadOwner->new(threads->self()->tid(), $opts->{app}, $opts->{thread}, $opts->{frag}));
		&{$opts->{main}}(@_);
	}, @args);
}
