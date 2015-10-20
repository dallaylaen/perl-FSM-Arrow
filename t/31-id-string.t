#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use FSM::Arrow::Event;

{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_state one_and_only => sub { 0 };
};

my $ev = FSM::Arrow::Event->new( type => 'foo', raw => 'bar' );
like ($ev->to_string, qr(\bEvent\b.*\bfoo\b), "Event class & type present");

my $ev2 = FSM::Arrow::Event->new( type => 'foo', raw => 'bar' ); # copy
isnt ($ev2->to_string, $ev->to_string, "Unique");

my $sm = My::SM->new;
like ($sm->sm_to_string, qr(\bMy::SM\b.*\bone_and_only\b),
	"SM Class & state present");
my $sm2 = My::SM->new;
isnt ($sm->sm_to_string, $sm2->sm_to_string, "Different machines differ");
note $sm->sm_to_string;

like ($sm->sm_schema->to_string, qr(\bFSM::Arrow\b.*\bMy::SM\b),
	"required info present in schema id string");
my $schema2 = $sm->sm_schema->clone;

isnt( $schema2->to_string, $sm->sm_schema->to_string, "SM clone has uniq id");

done_testing;

