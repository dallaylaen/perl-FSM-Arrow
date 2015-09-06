#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

BEGIN {
	if (!eval { require Class::XSAccessor; 1 }) {
		plan skip_all => "Class::XSAccessor not found, skipping accessor test";
		exit;
	};
};

{
	package My::SM;
	use FSM::Arrow qw(:class);
	use Class::XSAccessor
		getters => { schema => "schema", state => "state" },
		setters => { set_state => "state" },
	;

	sm_state one => sub { "two" };
	sm_state two => sub {}, final => 1;
};

my $sm = My::SM->new;
is ($sm->state, "one", "default state");
$sm->handle_event("xxx");
is ($sm->state, "two", "state changed");

done_testing;

