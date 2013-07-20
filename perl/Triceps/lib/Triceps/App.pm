#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Perl hepler methods for the App.

package Triceps::App;
use strict;

our $VERSION = 'v2.0.0';

use Carp;
use IO::Handle;
use IO::Socket::INET;

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
sub build($&) # ($appname, &builder)
{
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
sub globalNexus # (@opts)
{
	$global->makeNexus(@_, import => "none");
	return undef;
}

# Store the (dup of) file descriptor from a file handle.
# @param self - the App object or app name
# @param name - the storage name of the file descriptor
# @param file - the handle to store from
sub storeFile # ($self, $name, $file)
{
	my ($self, $name, $file) = @_;
	
	Triceps::App::storeFd($self, $name, fileno($file));
}

# Same as storeFile() but also closes the original file
# handle afterwards.
sub storeCloseFile # ($self, $name, $file)
{
	my ($self, $name, $file) = @_;
	
	Triceps::App::storeFd($self, $name, fileno($file));
	close($file);
}

# Load a dup of file descriptor from the App into a
# file handle object in a class that is a subclass of
# IO::Handle or otherwise supports the method new_from_fd().
# @param self - the App object or app name
# @param name - the storage name of the file descriptor
# @param mode - the file opening mode (either in r/w/a/r+/w+/a+
#        or </>/>>/+</+>/+>> format)
# @param class - class name to import the descriptor to
# @return - the object of the class created with the loaded 
#         file descriptor (a dup of it)
sub loadDupFileClass # ($self, $name, $mode, $class)
{
	confess "Triceps::App::loadDupFile: wrong argument count " . ($#_+1) . ", must be 4"
		unless ($#_ == 3);
	my ($self, $name, $mode, $class) = @_;
	# XXX this could leak the $fd if new_from_fd() fails
	return $class->new_from_fd(Triceps::App::loadDupFd($self, $name), $mode);
}

# A specialization of loadDupFileClass that creates an IO::Handle.
sub loadDupFile($$$) # ($self, $name, $mode)
{
	return loadDupFileClass(@_, "IO::Handle");
}

# A specialization of loadDupFileClass that creates an IO::Socket::INET.
sub loadDupSocket($$$) # ($self, $name, $mode)
{
	return loadDupFileClass(@_, "IO::Socket::INET");
}

1;
