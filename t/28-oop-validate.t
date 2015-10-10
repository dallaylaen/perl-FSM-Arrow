#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use FSM::Arrow;

my $sm = FSM::Arrow->new( strict => 1 );

$sm->add_state( one => sub {}, next => ["two", "three"] );

ok $sm->validate, "Undeclared next states exist";

$sm->add_state( two => sub {} );

$sm->add_state( three => sub {}, final => 1 );

ok $sm->validate, "Unmarked final state present";

$sm->add_transition( two => 'three' );

ok !$sm->validate, "Machine is ok";

done_testing;
