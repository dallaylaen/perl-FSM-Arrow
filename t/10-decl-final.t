#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_state start  => sub { 'finish', $_[1] };
	sm_state finish => sub { 'start',  $_[1] }, final => 1, accepting => "ok";
};

note "My::SM";
my $sm = My::SM->new;

is ($sm->is_final, 0, "!is_final");
is ($sm->accepting, 0, "!accepting");

is ($sm->handle_event("boo"), "boo", "state handle ok");
is ($sm->state, "finish", "came to final state");
is ($sm->is_final, 1, " is_final");
is ($sm->accepting, "ok", " accepting");

is ($sm->handle_event("far"), "far", "state handle value retained (final)");
is ($sm->state, "finish", "no transition from final state");

{
	package My::SM::ExactClone;
	use FSM::Arrow qw(:class);

	sm_init parent => "My::SM";
};

note "My::SM::ExactClone - repeat all tests above AS IS";
$sm = My::SM::ExactClone->new;
is ($sm->is_final, 0, "!is_final");
is ($sm->accepting, 0, "!accepting");

is ($sm->handle_event("boo"), "boo", "state handle ok");
is ($sm->state, "finish", "came to final state");
is ($sm->is_final, 1, " is_final");
is ($sm->accepting, "ok", " accepting");

is ($sm->handle_event("far"), "far", "state handle value retained (final)");
is ($sm->state, "finish", "no transition from final state");

{
	package My::SM::Another;
	use FSM::Arrow qw(:class);

	sm_init parent => 'My::SM';
	sm_state finish => sub { 'real_finish' };
	sm_state real_finish => sub {}, final => 1;
};

note "My::SM::Another";
$sm = My::SM::Another->new;

is ($sm->state, "start", "start");
$sm->handle_event(42);
is ($sm->state, "finish", "finish - now not final");
$sm->handle_event(42);
is ($sm->state, "real_finish", "real_finish IS final now");

note "My::SM::Err1 - test next + final exception";
eval {
	package My::SM::Err1;
	use FSM::Arrow qw(:class);

	sm_state only => sub {}, next => [qw(foo bar)], final => 1;
};
like ($@, qr/FSM::Arrow.*forbidden.*final/, "next+final = forbidden");
note "error was $@";

done_testing;
