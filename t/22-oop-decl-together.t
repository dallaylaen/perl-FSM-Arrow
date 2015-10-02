#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_state one => sub { "two" };
	sm_state two => sub { };
};

my $schema = My::SM->get_default_sm->clone;
$schema->add_state( one => sub { "three" } );
$schema->add_state( three => sub { } );

note "Machine 1 - spawn";
my $sm = $schema->spawn;
is (ref $sm, "My::SM", "Instance ref");
is ($sm->state, "one", "Initial state not changed");
$sm->handle_event("x");
is ($sm->state, "three", "Final state changed");

note "Machine 2 - force via new(); test are the same";
$sm = My::SM->new( schema => $schema );
is (ref $sm, "My::SM", "Instance ref");
is ($sm->state, "one", "Initial state not changed");
$sm->handle_event("x");
is ($sm->state, "three", "Final state changed");

note "Machine 3 - totally different";
my $schema3 = FSM::Arrow->new;
$schema3->add_state(foo => sub { "bar" });
$schema3->add_state(bar => sub { "bar" });

$sm = My::SM->new( schema => $schema3 );
is (ref $sm, "My::SM", "Instance ref");
is ($sm->state, "foo", "Initial state changed");
$sm->handle_event("x");
is ($sm->state, "bar", "Final state totally changed");

done_testing;
