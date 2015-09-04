#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_state one => sub { /bar/ and return two => 42; };
	sm_state two => sub {}, final => 1;
};

my $sm = My::SM->new;
$_ = "bar";
$sm->handle_event( "foo" );
is ($sm->state, "one", "State not changed");

$_ = "foo";
$sm->handle_event( "bar" );
is ($sm->state, "two", "State changed");

done_testing;

