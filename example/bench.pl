#!/usr/bin/env perl

# This is not really an exapmle, but rather a benchmarking tool.
# Thus state machines are made as simple as possible.
# See $0 --help

use strict;
use warnings;
use Time::HiRes qw(time);

use FindBin qw($Bin);
use lib "$Bin/../lib";

my @types;
{
	package empty;
	use FSM::Arrow qw(:class);

	sm_state one => sub {};
	sub descr { "Does nothing at all" };
	push @types, __PACKAGE__;

	package empty_final;
	use FSM::Arrow qw(:class);

	sm_state one => sub {}, final => 1;
	sub descr { "Does nothing at all, marked final" };
	push @types, __PACKAGE__;

	package flip;
	use FSM::Arrow qw(:class);

	sm_state flip => sub { "flop" };
	sm_state flop => sub { "flip" };
	sub descr { "2 alterating states, no callbacks" };
	push @types, __PACKAGE__;

	package flip_cb;
	use FSM::Arrow qw(:class);

	sm_state flip => sub { "flop" }, on_leave => sub { };
	sm_state flop => sub { "flip" }, on_enter => sub { };
	sub descr { "2 alterating states, with 1 callbacks each" };
	push @types, __PACKAGE__;

	package flip_xs;
	use FSM::Arrow qw(:class);

	use Class::XSAccessor
		setters => { set_state => "state" },
		getters => { state => "state", schema => "schema" };
	sm_state flip => sub { "flop" };
	sm_state flop => sub { "flip" };
	sub descr { "2 alterating states, no callbacks" };
	push @types, __PACKAGE__;

};

if (!@ARGV or $ARGV[0] eq '--help') {
	print <<"USAGE";
This is a state machine benchmarking/performance tool.
Usage: $0 <machine-type>=<iterations> ...
Available types: all @types
Output is "<tps> <time per i> <time> <count> <type> <description>\\n"
for each type=count given
USAGE
	exit 1;
};

while (@ARGV) {
	my ($type, $count) = shift() =~ /^(\S+)=(\d+)$/
		or die "Bad cli format, see $0 --help";

	if ($type eq 'all') {
		unshift @ARGV, map { "$_=$count" } @types;
		next;
	};

	$type->isa("FSM::Arrow::Instance")
		or die "Unknown machine type $type, see $0 --help";

	if ($count == 0) {
		printf "0 0 0 0 %s %s\n", $type, $type->descr;
	};

	my $sm = $type->new;
	my $i = $count;

	my $t0 = time;
	while ($i-->0) {
		$sm->handle_event("x");
	};
	my $spent = time - $t0;

	printf "%f %g %f %u %s (%s)\n"
		, $count/$spent, $spent/$count, $spent, $count, $type, $type->descr;
};
