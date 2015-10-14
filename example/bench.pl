#!/usr/bin/env perl

# This is not really an exapmle, but rather a benchmarking tool.
# Thus state machines are made as simple as possible.
# See $0 --help

use strict;
use warnings;
use Time::HiRes qw(time);

use FindBin qw($Bin);
use lib "$Bin/../lib";

BEGIN {
	# forbid XS accessors to keep benchmark objective
	$ENV{FSM_ARROW_NOXS} = 1 unless defined $ENV{FSM_ARROW_NOXS};
};

use FSM::Arrow::Event;

my $has_xs = eval { require Class::XSAccessor; 1; };
my $has_class_sm = eval { require Class::StateMachine; 1; };

my @types;
{
	package empty;
	use FSM::Arrow qw(:class);

	sm_state one => sub {};
	sub descr { "1 empty state" };
	push @types, __PACKAGE__;

	package empty_final;
	use FSM::Arrow qw(:class);

	sm_state one => sub {}, final => 1;
	sub descr { "1 empty final state" };
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
};
if ($has_xs) {
	package flip_xs;
	use FSM::Arrow qw(:class);

	Class::XSAccessor->import (
		accessors => { state => "state" },
		getters => { sm_schema => "sm_schema" }
	);
	sm_state flip => sub { "flop" };
	sm_state flop => sub { "flip" };
	sub descr { "2 alterating states, xs SM accessors" };
	push @types, __PACKAGE__;
};
{
	package typed;
	use FSM::Arrow qw(:class);

	sm_state flip => sub {};
	sm_transition "x" => 'flop';

	sm_state flop => sub {};
	sm_transition "x" => 'flip';

	sub descr { "2 alterating states, hard transitions used" };
	sub get_event {
		FSM::Arrow::Event->new( type => "x" );
	};
	push @types, __PACKAGE__;
};
if ($has_xs) {
	package typed_xs;
	use FSM::Arrow qw(:class);
	Class::XSAccessor->import(
		accessors => { state => "state" },
		getters => { sm_schema => "sm_schema" }
	);

	sm_state flip => sub {};
	sm_transition "x" => 'flop';

	sm_state flop => sub {};
	sm_transition "x" => 'flip';

	sub descr { "2 alterating states, hard transitions used, xs" };
	sub get_event {
		FSM::Arrow::Event->new( type => "x" );
	};
	push @types, __PACKAGE__;
};

{
	package typed_make_event;
	sub descr { "Makes event via callback" };

	use FSM::Arrow qw(:class);
	use FSM::Arrow::Util qw(sm_on_event_regex);
	sm_init on_event => sm_on_event_regex( regex => "(.)" );

	sm_state flip => sub {};
	sm_transition x => "flop";

	sm_state flop => sub {};
	sm_transition x => "flip";

	push @types, __PACKAGE__;
};

if ($has_xs) {
	package typed_make_ev_xs::event;
	our @ISA = qw(FSM::Arrow::Event);
	Class::XSAccessor->import(
		constructor => "new",
		getters => { type => "type", raw => "raw" },
	);

	package typed_make_ev_xs;
	sub descr { "Makes event via callback, all XS" };

	Class::XSAccessor->import(
		getters => { sm_schema => "sm_schema" },
		accessors => { state => "state" },
	);
	use FSM::Arrow qw(:class);
	use FSM::Arrow::Util qw(sm_on_event_regex);
	sm_init on_event => sm_on_event_regex(
		class => "typed_make_ev_xs::event", regex => "(.)" );

	sm_state flip => sub {};
	sm_transition x => "flop";

	sm_state flop => sub {};
	sm_transition x => "flip";

	push @types, __PACKAGE__;
};

if ($has_class_sm) {
	package salva;
	sub descr { "Use Class::StateMachine, if available" };

	# Use base by hand
	require Class::StateMachine;
	Class::StateMachine->import();
	our @ISA = qw(Class::StateMachine);

	use FSM::Arrow qw(:class);

	sub new {
		my $class = shift;
		my $self = $class->SUPER::new(@_);
		Class::StateMachine::bless( $self, $class, $self->{state} );
	};

	sm_state flip => sub { "flop" };
	sm_state flop => sub { "flip" };

	push @types, __PACKAGE__;
};

if (!@ARGV or $ARGV[0] eq '--help') {
	print <<"USAGE";
This is a state machine benchmarking/performance tool.
Usage: $0 <machine-type>=<iterations> ...
Available types: all @types
Output is "<tps> <rel_time> <total time> <count> <type> <description>\\n"
for each type=count given
rel_time = time per iteration / empty subroutine call duration
USAGE
	exit 1;
};

{
	package My::Bench::Unit;
	use Time::HiRes qw(time);

	sub test {
		my $self = shift;
		return;
	};

	sub get_unit {
		my $obj = bless {}, shift;
		my $count = shift;

		my $t0 = time;
		for (my $i=$count; $i-->0; ) {
			$obj->test();
		};
		return ((time - $t0) / $count);
	};
};

my $unit = My::Bench::Unit->get_unit(10000);

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
	my $event = $sm->can("get_event")
		? $sm->get_event
		: "x";

	my $t0 = time;
	while ($i-->0) {
		$sm->handle_event( $event );
	};
	my $spent = time - $t0;

	printf "%f %f %f %u %s (%s)\n"
		, $count/$spent, $spent/$count/$unit, $spent, $count, $type, $type->descr;
};

