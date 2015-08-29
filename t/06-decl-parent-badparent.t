#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

eval {
	package My::SM::Foo;
	use FSM::Arrow qw(:class);

	sm_init parent => "Test::More"; # non-sm class must fail
};
like $@, qr(^sm_init), "sm_init rejects non-SM parent class";
note $@;

done_testing;



