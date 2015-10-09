#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

{
	package My::SM;
	use FSM::Arrow qw(:class);
	sm_init strict => 1;

	sm_state foo => sub { $_ };

	sm_state bar => sub { $_ };
	sm_transition [] => 'foo';
};

my $sm = My::SM->new;

eval {
	$sm->handle_event("bar");
};
like $@, qr(forbidden), "next == [] - no go";

$sm = My::SM->new( state => "bar" );
eval {
	$sm->handle_event("foo");
};
is $@, '', "transition to foo = ok";
is $sm->state, "foo", "state as expected";


done_testing;
