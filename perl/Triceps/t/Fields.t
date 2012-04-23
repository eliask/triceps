#
# (C) Copyright 2011-2012 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# Test of the field list processing.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Triceps.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 20 };
use Triceps;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#########################
# fields()

@res = &Triceps::Fields::filter("Caller", [ 'abc', 'def' ], undef);
ok(join(",", map { defined $_? $_ : "-" } @res), "abc,def"); # all positive if no patterns

@res = &Triceps::Fields::filter("Caller", [ 'abc', 'def', 'ghi' ], [ 'abc', 'def' ] );
ok(join(",", map { defined $_? $_ : "-" } @res), "abc,def,-");

@res = &Triceps::Fields::filter("Caller", [ 'abc', 'def', 'ghi' ], [ '!abc' ] );
ok(join(",", map { defined $_? $_ : "-" } @res), "-,-,-"); # check for default being "throwaway" even with purely negative
@res = &Triceps::Fields::filter("Caller", [ 'abc', 'def', 'ghi' ], [ ] );
ok(join(",", map { defined $_? $_ : "-" } @res), "-,-,-"); # empty pattern means throw away everything

@res = &Triceps::Fields::filter("Caller", [ 'abc', 'def', 'ghi' ], [ '!abc', '.*' ] );
ok(join(",", map { defined $_? $_ : "-" } @res), "-,def,ghi");

@res = &Triceps::Fields::filter("Caller", [ 'abc', 'adef', 'gahi' ], [ '!abc', 'a.*' ] );
ok(join(",", map { defined $_? $_ : "-" } @res), "-,adef,-"); # first match wins, and check front anchoring

@res = &Triceps::Fields::filter("Caller", [ 'abc', 'adef', 'gahi' ], [ '...' ] );
ok(join(",", map { defined $_? $_ : "-" } @res), "abc,-,-"); # anchoring

@res = &Triceps::Fields::filter("Caller", [ 'abc', 'def', 'ghi' ], [ '!a.*', '.*' ] );
ok(join(",", map { defined $_? $_ : "-" } @res), "-,def,ghi"); # negative pattern

@res = &Triceps::Fields::filter("Caller", [ 'abc', 'def', 'ghi' ], [ '.*/second_$&' ] );
ok(join(",", map { defined $_? $_ : "-" } @res), "second_abc,second_def,second_ghi"); # substitution

@res = &Triceps::Fields::filter("Caller", [ 'abc', 'defg', 'ghi' ], [ '(.).(.)/$1x$2' ] );
ok(join(",", map { defined $_? $_ : "-" } @res), "axc,-,gxi"); # anchoring and numbered sub-expressions

# missing fields in fields()
eval {
	@res = &Triceps::Fields::filter("Caller", [ 'abc', 'def', 'ghi' ], [ 'cba', 'fed' ] );
};
ok($@ =~ /Caller: result definition error:
  the field in definition 'cba' is not found
  the field in definition 'fed' is not found
The available fields are:
  abc, def, ghi
/);

eval {
	@res = &Triceps::Fields::filter("Caller", [ 'abc', 'def', 'ghi' ], [ 'cba/abc', '!fed' ] );
};
ok($@ =~ /Caller: result definition error:
  the field in definition 'cba\/abc' is not found
  the field in definition '!fed' is not found
The available fields are:
  abc, def, ghi
/);
#print STDERR "$@\n";

#########################
# filterToPairs() - touch-test, since it works through filter()

@res = &Triceps::Fields::filterToPairs("Caller", [ 'abc', 'defg', 'ghi' ], [ '(.).(.)/$1x$2' ] );
ok(join(",", map { defined $_? $_ : "-" } @res), "abc,axc,ghi,gxi"); # anchoring and numbered sub-expressions

eval {
	@res = &Triceps::Fields::filterToPairs("Caller", [ 'abc', 'def', 'ghi' ], [ 'cba/abc', '!fed' ] );
};
ok($@ =~ /Caller: result definition error:
  the field in definition 'cba\/abc' is not found
  the field in definition '!fed' is not found
The available fields are:
  abc, def, ghi
/);

#########################
# isArrayType()
ok(!&Triceps::Fields::isArrayType("int32"));
ok(&Triceps::Fields::isArrayType("int32[]"));
ok(!&Triceps::Fields::isArrayType("string"));
ok(!&Triceps::Fields::isArrayType("uint8"));
ok(!&Triceps::Fields::isArrayType("uint8[]"));
