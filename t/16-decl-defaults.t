#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

my $sm_schema;
{
	package My::SM;
	use FSM::Arrow qw(:class);

	$sm_schema = sm_state one => sub {};
};

my $sm = My::SM->new;
is ( $sm->state, $sm_schema->initial_state, "state default" );
is_deeply ( $sm->sm_schema, $sm_schema, "sm_schema default");

my $schema2 = $sm_schema->clone;
$schema2->add_state( two => sub {}, initial => 1 );

my $sm2 = $schema2->spawn;
is (ref $sm2, "My::SM", "spawned ref");
is ($sm2->state, "two", "upd. sm => different state");
is_deeply ($sm2->sm_schema, $schema2, "upd. sm returned by inst");

done_testing;
