#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

{
	package My::SM;
	use Scalar::Util qw(blessed);

	use FSM::Arrow qw(:class);
	use FSM::Arrow::Event;

	sm_init on_check_event => sub {
		return FSM::Arrow::Event -> new (type => shift);
	}, on_state_change => sub {
		blessed $_ and $_->isa("FSM::Arrow::Event")
		 	or die "Blessed event not found (TODO check via test)";
	};

	sm_state one => sub {};
	sm_transition foo => "two";

	sm_state two => sub {};
	sm_transition bar => "three";

};

my $sm = My::SM->new;
is ($sm->state, "one", "initial state" );
$sm->handle_event( "xxx" );
is ($sm->state, "one", "initial state (still)" );
$sm->handle_event( "foo" );
is ($sm->state, "two", "state changed" );

done_testing;
