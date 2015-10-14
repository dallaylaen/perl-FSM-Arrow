#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_init on_state_change => sub { "change" };
	sm_state one => sub { "two" }, next => [ "two" ]
		, on_leave => sub { "leave" };
	sm_state two => sub {}, final => 1
		, on_enter => sub { "enter" };

	package My::SM2;
	use FSM::Arrow qw(:class);

	sm_init parent => 'My::SM';
	# and change nothing ;)
};

my $sm = My::SM2->new->sm_schema;

is_deeply( [ $sm->list_states ], [ "one", "two" ], "States ok");

my $inspect;

note "Inspect state: one";
$inspect = $sm->get_state("one");
is        $inspect->{initial}, 1,         " initial";
is        $inspect->{final},   0,         "!final";
is_deeply $inspect->{next},    [ "two" ], " next";
ok       !$inspect->{on_enter},           "!on_enter";
ok        $inspect->{on_leave},           " on_leave";
is        $inspect->{on_leave} && $inspect->{on_leave}->(),
                               "leave",   "callback ok";

note "Inspect state: two";
$inspect = $sm->get_state("two");
is        $inspect->{initial}, 0,         "!initial";
is        $inspect->{final},   1,         " final";
is        $inspect->{next},    undef,     "!next";
ok        $inspect->{on_enter},           " on_enter";
ok       !$inspect->{on_leave},           "!on_leave";
is        $inspect->{on_enter} && $inspect->{on_enter}->(),
                               "enter",   "callback ok";


done_testing;

