#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use FSM::Arrow::Event;

{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_state 'foo';
	sm_transition bar => 'bar';

	sm_state 'bar', final => 1;
};

my $sm = My::SM->new;
my $ev1 = FSM::Arrow::Event->new( type => 'xxx' );
my $ev2 = FSM::Arrow::Event->new( type => 'bar' );

eval { $sm->handle_event( "Scalar, no luck" ) };
like $@, qr([Uu]nexpected.*'foo'), "Error as expected (plain)";
is ($sm->state, "foo", "state stays" );

eval { $sm->handle_event( $ev1 ) };
like $@, qr([Uu]nexpected.*'xxx'.*'foo'), "Error as expected (blessed)";
is ($sm->state, "foo", "state stays" );

$sm->handle_event( $ev2 );
is ($sm->state, "bar", "state switched" );

eval { $sm->handle_event( $ev2 ) };
like $@, qr([Uu]nexpected.*'bar'.*'bar'), "Error as expected (final)";
is ($sm->state, "bar", "state stays" );


done_testing;
