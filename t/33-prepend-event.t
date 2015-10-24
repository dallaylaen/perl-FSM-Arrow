#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

my @trace;
{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_init strict => 1, on_state_change => sub { push @trace, $_ };
	sm_state 1 => sub { $_[0]->sm_prepend_event( $_+1 ); 2; }, next => [2];
	sm_state 2 => sub { 3; }, next => [3];
	sm_state 3 => sub { 4; }, next => [4];
	sm_state 4 => sub { 1; }, next => [1];

	sm_validate;

	package My::SM2;
	use FSM::Arrow qw(:class);

	sm_init strict => 1, parent => 'My::SM';
	sm_state 1 => sub { $_[0]->handle_event( $_+1 ); 2; }, next => [2];
	sm_validate;
};

my $sm;

$sm = My::SM->new;
$sm->handle_event(1,3);
is ($sm->state, "4", "State as expected");
is_deeply( \@trace, [1,2,3], "Events reordered");
@trace = ();

$sm = My::SM2->new;
$sm->handle_event(1,3);
is ($sm->state, "4", "State as expected");
is_deeply( \@trace, [1,3,2], "Events unordered");
@trace = ();

done_testing;
