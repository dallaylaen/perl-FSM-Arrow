#!/usr/bin/env perl

use warnings;
use strict;
use Test::More;

use FSM::Arrow;

my $sm_schema = FSM::Arrow->new;
$sm_schema->add_state( empty => sub {
	return ("first", $1) if $_[1] =~ /foo(.*)/ } );
$sm_schema->add_state( first => sub {
	return ("second", $1) if $_[1] =~ /bar(.*)/ } );
$sm_schema->add_state( second => sub {} );

my $machine = $sm_schema->spawn;

like ( $sm_schema->id, qr(FSM::Arrow), "id present");

is( ref $machine, 'FSM::Arrow::Instance', "Machine instance spawn ok");
is( $machine->state, 'empty', "first state = initial state");

my $ret = $machine->handle_event("42");
is ($machine->state, "empty", "irrelevant event = no progress");
is ($ret, undef, "returns undef");

$ret = $machine->handle_event("footer");
is ($machine->state, "first", "relevant event = state shift");
is ($ret, "ter", "return value gets through");

done_testing;
