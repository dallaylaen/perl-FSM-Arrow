#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

my @args;
{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_init on_state_change => sub { @args = @_ };
	sm_state one => sub { "two" };
	sm_state two => sub { "one" };
};

my $sm = My::SM->new;
$sm->handle_event ("foo");
is_deeply( \@args, [ $sm, qw(one two foo) ], "callback args 1->2");

$sm->handle_event ("bar");
is_deeply( \@args, [ $sm, qw(two one bar) ], "callback args 2->1");

done_testing;
