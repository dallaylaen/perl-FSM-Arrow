#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_state start  => sub { 'finish', $_[1] };
	sm_state finish => sub { 'start',  $_[1] }, final => 1;
};

my $sm = My::SM->new;

is ($sm->handle_event("boo"), "boo", "state handle ok");
is ($sm->state, "finish", "came to final state");

is ($sm->handle_event("far"), "far", "state handle value retained (final)");
is ($sm->state, "finish", "no transition from final state");

{
	package My::SM::Another;
	use FSM::Arrow qw(:class);

	sm_init parent => 'My::SM';
	sm_state finish => sub { 'real_finish' };
	sm_state real_finish => sub {}, final => 1;
};

$sm = My::SM::Another->new;

is ($sm->state, "start", "start");
$sm->handle_event(42);
is ($sm->state, "finish", "finish - now not final");
$sm->handle_event(42);
is ($sm->state, "real_finish", "real_finish IS final now");

eval {
	package My::SM::Err1;
	use FSM::Arrow qw(:class);

	sm_state only => sub {}, next => [qw(foo bar)], final => 1;
};
like ($@, qr/FSM::Arrow.*forbidden.*final/, "next+final = forbidden");
note "error was $@";

done_testing;
