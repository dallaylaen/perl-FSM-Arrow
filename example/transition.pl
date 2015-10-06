#!/usr/bin/env perl

# A really stupid example showing transition-based state machine.
# Here states are modelling continent names
# and transition types are based on four cardinal directions.
# We left out Antarctica for now.
# The example script will follow directions given via stdin,
# printing stupid comments about this imaginary travel.

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";

{
	package My::Earth;
	use FSM::Arrow qw(:class);
	use FSM::Arrow::Event;

	sm_init on_check_event => FSM::Arrow::Event->generator_regex(
			regex => qr<(east|west|north|south|stay)>i
		),
		on_state_change => sub { print "Going from $_[1] to $_[2]!\n" };

	sm_state Europe => sub { };
	sm_transition east  => "Asia";
	sm_transition west  => "North America";
	sm_transition south => "Africa";

	sm_state Asia => sub { 0 => print "Ommmmmm\n" };
	sm_transition east  => "North America";
	sm_transition west  => "Europe";
	sm_transition south => "Australia";

	sm_state "North America" => sub { },
		on_enter => sub { print "Don't forget to pay taxes\n" };
	sm_transition east  => "Europe";
	sm_transition west  => "Asia";
	sm_transition south => "South America";

	sm_state Africa => sub {};
	sm_transition east  => "Australia";
	sm_transition west  => "South America";
	sm_transition north => "Europe";

	sm_state "South America" => sub { },
		on_leave => sub { print "Don't cry for me Argentinaaaa!...\n" };
	sm_transition east  => "Africa";
	sm_transition west  => "Australia";
	sm_transition north => "North America";

	sm_state Australia => sub {};
	sm_transition east  => "South America";
	sm_transition west  => "Africa";
	sm_transition north => "Asia";
};

my $sm = My::Earth->new;

while (<>) {
	eval { $sm->handle_event( lc $_ ); 1 }
		or print "Error: $@";
};

