#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

eval {
	package My::SM::Foo;
	use FSM::Arrow qw(:class);

	sm_state one => sub {};
	sm_state one => sub {};

	1;
};
like $@, qr(already), "sm_init rejects non-SM parent class";
note $@;

eval {
	package My::SM::Foo;
	use FSM::Arrow qw(:class);

	sm_state two => sub {}, next => [ {}, 1, 2 ];

	1;
};
like $@, qr(FSM::Arrow), "sm_init rejects non-SM parent class";
note $@;

done_testing;
