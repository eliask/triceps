#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# An example of traffic accounting aggregated to multiple levels,
# as a multithreaded pipeline.

#########################

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 1 };
use Triceps;
use Triceps::X::TestFeed qw(:all);
use Carp;
ok(1); # If we made it this far, we're ok.

use strict;

#########################

package Treffic1;

sub TrafficApp {
};
