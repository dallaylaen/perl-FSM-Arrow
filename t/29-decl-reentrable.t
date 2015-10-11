#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

{
	package My::SM;
	use FSM::Arrow qw(:class);

	our $count;
	sm_init on_state_change => sub { $count++ };

	my $lock; # lock to ensure we're not recursing
	sm_state 1 => sub {
		$lock++ and die "Recusrion detected! Reentrability lost";
		$_[0]->handle_event("x");
		$lock = 0;
		2
	};
	sm_state 2 => sub { 3 };
	sm_state 3 => sub { 4 };
	sm_state 4 => sub {}, final => 1;
};

my $sm = My::SM->new;

eval { $sm->handle_event("x"); };
is ($@, '', "No recursion detected" );
is ($sm->state, 3, "1+1 state changes" );

$sm->state(1);
eval { $sm->handle_event("x", "x"); };
is ($@, '', "No recursion detected" );
is ($sm->state, 4, "2+1 state changes" );

$sm->state(2);
$sm->handle_event("x");
is ($sm->state, 3, "1+0 state changes" );


done_testing;
