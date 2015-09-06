#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_state one => sub { "two" };
	sm_state two => sub { "three" };
	sm_state three => sub {};
};

my $sm = My::SM->new;
is ($sm->state, "one", "default state");

$sm = My::SM->new( state => "two" );
is ($sm->state, "two", "overridden state");

done_testing;
