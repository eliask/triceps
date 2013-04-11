#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Perl methods for the TrieadOwner class.

package Triceps::TrieadOwner;

our $VERSION = 'v1.0.1';

use Carp;

use strict;

# Remember a file that has been just opened. This file will be revoked when
# the thread is requested dead.
# @param $file - the file glob object (such as *STDIN or one returned by IO::Socket::INET->new())
sub track(*) # ($self, $file)
{
	my $fd = fileno($_[1]) or confess "Triceps::TrieadOwner::open(): can not get the file descriptor";
	$_[0]->trackFd($fd);
}

# Forget a file before it gets closed. If this function is not called properly before
# closing a file descriptor, the thread shutdown will corrupt a random file descriptor
# that happens to have the same id. Better yet, use the TrieadOwner::close().
# @param $file - the file glob object (such as *STDIN or one returned by IO::Socket::INET->new())
sub forget(*) # ($self, $file)
{
	my $fd = fileno($_[1]) or confess "Triceps::TrieadOwner::forget(): can not get the file descriptor";
	$_[0]->forgetFd($fd);
}

# Forget a file and close it conveniently.
# @param $file - the file glob object (such as *STDIN or one returned by IO::Socket::INET->new())
sub close(*) # ($self, $file)
{
	my $fd = fileno($_[1]) or confess "Triceps::TrieadOwner::forget(): can not get the file descriptor";
	$_[0]->forgetFd($fd);
	close($_[1]);
}
