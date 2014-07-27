#
# (C) Copyright 2011-2014 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#

use 5.008000;
use strict;
use warnings;

# This function must be outside the package.
sub _Triceps_eval_ {
	no warnings 'all'; # shut up the warnings from eval
	# print "DBG code:\n$_[0]\n";
	my $c = eval $_[0];
	# print "DBG compiled $c\n";
	# print "DBG error $@\n";
	die $@ if ($@);
	return $c;
}

package main;

# Triceps uses SIGUSR2 to interrupt the threads reading from file descriptors,
# so start by setting a dummy handler on it. It gets inherited by all the threads.
$SIG{USR2} = sub {};

package Triceps;

use Carp;

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Triceps ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = 'v2.0.0';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
	#print STDERR "AUTOLOAD '$AUTOLOAD'\n";
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Triceps::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

# comparisons that are called from the code in C++ 
sub _compareText {
	$_[0] cmp $_[1];
}

sub _compareNumber {
	$_[0] <=> $_[1];
}

# flie close called from the C++ code
sub _close {
	close($_[0]);
}

# The default label clearing code.
# Undefines all the values referred to by the reference arguments.
# Then undefines all the arguments.
sub clearArgs 
{
	for my $v (@_) {
		my $rt = ref $v;
		if ($rt eq '') {
			# nothing
		} elsif ($rt eq 'SCALAR') {
			undef $$v;
		} elsif ($rt eq 'ARRAY') {
			undef @$v;
		} elsif ($rt eq 'HASH') {
			undef %$v;
		} else {
			# the blessed types are normally hashes, so take this guess
			eval { undef %$v; };
		}
		undef $v;
	}
}

# The default thread joining code, by the thread id.
sub joinTid {
	threads->object($_[0])->join();
};

require XSLoader;
XSLoader::load('Triceps', $VERSION);

# Set up a dummy handler in C, or the more recent Perl versions (like 5.19)
# crash when they receive a signal at an inopportune time.
Triceps::sigusr2_setup();

# Preloaded methods go here.

# Subpackages go here
require Triceps::Fields;
require Triceps::Unit;
require Triceps::UnitTracerPerl;
require Triceps::UnitTracerStringName;
require Triceps::Row;
require Triceps::Rowop;
require Triceps::Label;
require Triceps::Table;
require Triceps::TableType;
require Triceps::AggregatorContext;
require Triceps::Opt;
require Triceps::SimpleOrderedIndex;
require Triceps::SimpleAggregator;
require Triceps::Collapse;
require Triceps::LookupJoin;
require Triceps::JoinTwo;
require Triceps::Triead;
require Triceps::TrieadOwner;
require Triceps::App;
require Triceps::Braced;
require Triceps::Code;
# The X subpackages contain the eXperimental, eXample, eXtraneous code.
require Triceps::X::SimpleServer;
require Triceps::X::DumbClient;
require Triceps::X::TestFeed;
require Triceps::X::Tql;

# Autoload methods go after =cut, and are processed by the autosplit program.

# The special variables.
our $_CROAK_MSG; # used to temporarily store the croak message in the XS code
our $_DEFAULT_CLEAR_LABEL = \&clearArgs; # used if the label's clear function is undef
our $_JOIN_TID = \&joinTid; # used in the PerlTrieadJoin for harvesting

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Triceps - Perl interface to the Triceps CEP engine

=head1 SYNOPSIS

  use Triceps;

=head1 DESCRIPTION

Triceps is an innovative Complex Event Processing engine, embeddable into the
scripting language. At the moment the only language supported is Perl
(and of course the native C++).

Currently all the documentation is available only in the PDF and
HTML formats. The man pages will be added later.

=head2 EXPORT

None by default.

=head1 SEE ALSO

Triceps home page: http://triceps.sf.net

Triceps page at SourceForge: http://sourceforge.net/projects/triceps/

The documentation in PDF: http://triceps.sf.net/docs-latest/guide.pdf

The documentation in HTML: http://triceps.sf.net/docs-latest/guide.html

The blog with the latest information: http://babkin-cep.blogspot.com/

=head1 AUTHOR

Sergey A. Babkin, E<lt>babkin@users.sf.netE<gt> or E<lt>sab123@hotmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2012 by Sergey A.Babkin

This library distributed under the Triceps edition of Lesser GPL license version 3.0.


=cut
