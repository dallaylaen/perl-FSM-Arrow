#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_state start => sub { "end" => 42 }, on_leave => sub { "leave" },
		next => [ "end" ];
	sm_state end => sub { "nowhere_to_go" }, on_enter => sub { "enter" },
		final => 1, accepting => "ok";
};

my $sm = My::SM->new->sm_schema;

is_deeply ( [ sort $sm->list_states ], [ qw(end start) ], "list_states" );
is ([$sm->list_states]->[0], "start", "initial state comes first");

my $inspect;

note "inspect 'start'";
$inspect = $sm->get_state( "start" );
is ($inspect->{initial},       1,           " initial");
is ($inspect->{final},         0,           "!final");
is_deeply($inspect->{next},    [ "end" ],   " next");
is ($inspect->{on_enter},      undef,       "!on_enter");
is (ref $inspect->{on_leave},  'CODE',      " on_leave");
is ($inspect->{on_leave}->(),  "leave",     " on_leave (result)");
is ($inspect->{accepting},     0,           "!accepting");
is_deeply( [ sort keys %$inspect ],
	[ sort qw( name handler initial final next on_enter on_leave accepting ) ],
	"No extra keys")
		or diag explain $inspect;

note "inspect 'end'";
$inspect = $sm->get_state( "end" );
is ($inspect->{initial},       0,           "!initial");
is ($inspect->{final},         1,           " final");
is_deeply($inspect->{next},    undef,       "!next");
is ($inspect->{on_leave},      undef,       "!on_leave");
is (ref $inspect->{on_enter},  'CODE',      " on_enter");
is ($inspect->{on_enter}->(),  "enter",     " on_enter (result)");
is ($inspect->{accepting},     "ok",        " accepting");
is_deeply( [ sort keys %$inspect ],
	[ sort qw( name handler initial final next on_enter on_leave accepting ) ],
	"No extra keys");

eval {
	$sm->get_state("no_exist");
};
note "Error was", $@;
like ($@, qr([Nn]o state), "Getting absent states not allowed");

note $sm->pretty_print;

done_testing;
