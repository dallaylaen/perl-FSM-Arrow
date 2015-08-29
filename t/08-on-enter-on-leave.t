#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

my %stat;

{
	package My::SM::Foo;
	use FSM::Arrow qw(:class);

	sm_state start => sub { $_[1] =~ /foo/ and return running => 1 }
		, on_leave => sub { $stat{leave}++ };

	sm_state running => sub { $_[1] =~ /baz/ and return finish => 1 };

	sm_state finish => sub { }
		, on_enter => sub { $stat{enter}++ };
};

my $sm = My::SM::Foo->new;

$sm->handle_event( "zzz" );
is( $sm->state, "start", "start");
is_deeply (\%stat, {}, "no enter, no leave");

$sm->handle_event( "foo" );
is( $sm->state, "running", "running");
is_deeply (\%stat, { leave => 1 }, "left 1 state");

$sm->handle_event( "bar" );
is( $sm->state, "running", "running 2");
is_deeply (\%stat, { leave => 1 }, "left 1 state - still");

$sm->handle_event( "baz" );
is( $sm->state, "finish", "finish");
is_deeply (\%stat, { leave => 1, enter => 1 }, "final state reached");

done_testing;
