#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use FSM::Arrow::Util qw(sm_on_event_regex);

my $ev;
my $gen;

note "Rex generator 1";
$gen = sm_on_event_regex( regex => qr/(\w+)/ );

$ev = $gen->( "foo bar" );
is (ref $ev, "FSM::Arrow::Event", "Ev ref holds");
is ($ev->type, "foo", "Ev type holds");
is ($ev->raw, "foo bar", "Ev raw holds");

$ev = $gen->();
is ($ev->type, "__STOP__", "STOP ev type holds");

eval { $gen->("???"); };
like ($@, qr(event.*match), "Bad events shall not pass");

if ($] > 5.010) {
	note "Rex generator 2 - with named capture";
	$gen = sm_on_event_regex(
		regex => q/((\d+\.)\s+)?(?<type>[a-z]\w*)(\s+(?<number>\d+))?/,
	);

	$ev = $gen->("1. aaa 42");
	is ($ev->type, "aaa", "type holds");
	is ($ev->{number}, 42, "other capture holds");
};

done_testing;
