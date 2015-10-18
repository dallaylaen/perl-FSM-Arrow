#!/usr/bin/env perl

# Phone call simulator.
# Network user is represented by a simple state machine:
#
# offline -> online
# online  -> offline,  calling, ringing
# calling -> busy,     online
# ringing -> busy,     online
# busy    -> online,   offline
#
# Users have their file handles, and optionally a peer user they're currently
# talking to.
# Making a separate machine for call itself is possible,
# but this "small example" won't fit Pierre Fermat's margins already.
#
# At least the possibility of state machines to coexist and send events to
# each other is demonstrated here.

# This example is run as `perl ae-phone.pl <nnnn>`
# Then `nc localhost <nnnn>`
# User commands (in nc) include:
# join <nnn> - register with the "network" using that number
# dial <nnn> - call other user
# part       - go offline (available at any state)
# bye        - hang up during call

use strict;
use warnings;
use 5.010; # we'll need named captures - sorry, 5.8...
use AnyEvent::Strict;
use AnyEvent::Socket;
use AnyEvent::Handle;

# Always want latest & greatest FSM
use FindBin qw($Bin);
use lib "$Bin/../lib";

# State machine definitions - this would be a couple .pm files in real life
{
	# We'll use custom event class, very stupid but somewhat helpful.
	package My::Event;
	use parent 'FSM::Arrow::Event';
	use Class::XSAccessor accessors => { is_mt => 'is_mt', number => 'number' };
	use overload '""' => \&as_string;

	# is_mt means "mobile terminated", that is, FROM network TO user
	# Events coming FROM user TO network are called "mobile originating", or MO

	sub as_string {
		my $self = shift;
		return join " ", $self->type, $self->number // ()
			, $self->is_mt ? "[mt]" : "[mo]";
	};
	sub peer {
		return My::SM::Handset->get_user( $_[0]->number );
	};

	# The state machine. It's REALLY big and nasty.
	# But you production app's one will be even bigger and nastier.
	package My::SM::Handset;
	use FSM::Arrow qw(:class);
	use FSM::Arrow::Util qw(:all);

	# Set up some accessors here...
	use Class::XSAccessor
		accessors => { number => 'number', peer => 'peer', fh => 'fh' }
		, getters => { id => 'id' };

	my $id;
	sub new {
		my $class = shift;
		return $class->SUPER::new( @_, id => ++$id );
	};

	# Start out a machine first, note a lot of callbacks
	sm_init strict => 1,
		on_event => sm_on_event_regex (
			class => "My::Event",
			regex => qr/(?<type>[a-z][a-z0-9]*)(\s\D*(?<number>\d+))?/,
			undef => 'part',
		),
		on_state_change => sub {
			my $q = $_[0]->sm_queue;
			$_[0]->reply("# state $_[1] => $_[2] via $_, pending @$q");
		},
		on_return => sub {
			my $self = shift;
			$self->reply( "# OK: @", $self->state, ' ', shift // '(silent)' );
		},
		on_error => sub {
			my ($self, $err, $queue) = @_;
			warn "Error in handler: $err, pending=[@$queue]";
			$self->reply( "# ERROR: @", $self->state, ' ', $err );
		};

	# First state = offline
	# Note: we prefix mt events with mt_
	# The handler sub (on_wrong_event) should NOT be reached here,
	# but some nice error messages are better than default `croak`
	# which will be used if event handler is omitted
	sm_state 'offline' => \&on_wrong_event, on_enter => sub {
		my $self = shift;
		$self->sign_off;

		$self->notify_peer( "bye" );
		$self->peer( undef );
		$self->reply ( "!offline" );
	};
	sm_transition join => 'online', handler => sub {
		my $self = shift;
		die "join requires number" unless $_->number;

		$self->sign_on($_->number);
		"Joined as ".$self->number;
	};
	sm_transition mt_bye => 0; # transition => 0 == silently skip this event

	# The second state. Entering online state may mean termination of a call,
	# so if we're talking to someone (peer) let them know we're off the line
	sm_state 'online' => \&on_wrong_event, on_enter => sub {
		my $self = shift;
		$self->notify_peer( "bye" ) unless $_->is_mt;
		$self->peer( undef );
		$self->reply( "!online ", $self->number );
	};
	sm_transition part => 'offline', handler => sub { "Gone offline" };
	sm_transition dial => 'calling', handler => sub {
		my $self = shift;
		die "dial requires number" unless $_->number;

		# If no peer found, say goodbye to ourselves
		# NOTE This is a short-circuit transition in fact:
		# switch state, process event leading from that state immediately
		# This may be used if one wants hard transition, BUT
		# extra check is required within transition handler.
		my $peer = $_->peer;
		if (!$peer) {
			$self->handle_event(
				My::Event->new( type=>'mt_bye', is_mt=>1, number=>$_->number)
			);
			return;
		};

		$self->peer( $peer );
		$self->notify_peer( "ring" );
		"Calling ".$peer->number;
	};
	sm_transition mt_ring => 'ringing', handler => sub {
		my $self = shift;
		$self->peer( $_->peer );
		return;
	};

	sm_state 'calling' => \&on_wrong_event;
	sm_transition part => 'offline', handler => sub { "Gone offline" };
	sm_transition mt_y => 'busy',    handler => sub { $_->is_mt or die "Cannot self-accept" };
	sm_transition mt_bye  => 'online',  handler => sub { "Call rejected" };
	sm_transition mt_ring => 0, handler => sub {
		my $self = shift;
		$self->notify_peer( bye => $_ );
	};

	sm_state 'ringing' => \&on_wrong_event, on_enter => sub {
		$_[0]->reply( "!ringing ", $_->number, ", accept? (y/n)" );
	};
	sm_transition part => 'offline', handler => sub { "Gone offline" };
	sm_transition n    => 'online',  handler => sub { "Hangup"; };
	sm_transition mt_bye => 'online', handler => sub { "Peer hangup" };
	sm_transition y    => 'busy',    handler => sub {
		my $self = shift;
		$self->notify_peer( "y" );
		return;
	};
	sm_transition mt_ring => 0,         handler => sub {
		my $self = shift;
		$self->notify_peer( bye => $_ );
	};

	sm_state 'busy' => \&on_wrong_event, on_enter => sub {
		$_[0]->reply( "!busy ", $_[0]->peer ? $_[0]->peer->number : "(...)");
	};
	sm_transition part => 'offline', handler => sub { "Gone offline" };
	sm_transition bye  => 'online',  handler => sub { "Hangup" };
	sm_transition mt_bye  => 'online',  handler => sub { "Peer hangup" };
	sm_transition mt_ring => 0,         handler => sub {
		my $self = shift;
		$self->notify_peer( bye => $_ );
	};

	# Self check state definitions for correctness
	sm_validate;

	# Simplify sending events to peer.
	sub notify_peer {
		my ($self, $str, $event) = @_;

		my $peer = $event ? $event->peer : $self->peer;
		return unless $peer;

		my $ev = My::Event->new(
			type   => "mt_$str",
			number => $self->number,
			is_mt  => 1,
		);

		return $peer->handle_event( $ev );
	};

	sub on_wrong_event {
		my ($self, $event) = @_;

		my $msg = "Inappropriate event in state ".$self->state.": ".$event;
		if (!$event->is_mt) {
			$self->reply($msg);
			$self->reply("!".$self->state);
			return;
		} elsif (!$self->peer || ( $self->peer->number // '' ne $event->number )) {
			# I've added this part when I got in trouble developing this example
			# It's never called now.
			# Developing state-based apps under anyevent *is* hard sometimes
			warn join " ", "PEER MISMATCH:"
				, "self=", $self->number // '(undef)'
				, (($self->peer && $self->peer->number) // '(undef)')
				, '!=', $event ;
		};
		die $msg;
	};

	# Some primitive data storage. Imagine a DB here!
	our %users;
	sub sign_on {
		my ($self, $number) = @_;
		die "Number $number already in use"
			if $users{$number};

		$self->number( $number );
		$users{$number} = $self;
		return $self;
	};
	sub sign_off {
		my $self = shift;
		my $number = delete $self->{number};
		delete $users{$number} if $number;
		$number;
	};
	sub get_user {
		my ($class, $number) = @_;
		return $users{$number || ''};
	};
	sub get_all {
		return values %users;
	};

	# IO primitives
	sub on_input {
		my ($self, $raw) = @_;

		eval { $self->handle_event($raw) }
			if !defined $raw or $raw =~ /\S/;

		# This is for scriptability. If command failed, reset state
		# on_return/on_error are to handle return values & $@ output
		$self->reply( '!', $self->state )
			if ($@);
	};

	# Send data back to the user.
	sub reply {
		my $self = shift;
		my $msg = join "", map { $_ // '(undef)' } @_;
		$msg =~ s/\s*$/\n/s;

		if ($self->fh) {
			$self->fh->push_write($msg);
		} else {
			print $msg;
		};
	};
};
# end state machine definitions

### Here comes the main loop

my $port = shift;

if (!$port) {
	# offline mode
	# just check machine lives

	my $sm = My::SM::Handset->new;
	while (<>) {
		$sm->on_input($_);
	};

	exit 0;
};

# TODO want --help and --show (for showing machine) here

# Listen to socket, create machines on the fly
my $listen = tcp_server undef, $port, sub {
	my ($fh, $host, $port) = @_;

	my $machine = My::SM::Handset->new;
	my $handle = AnyEvent::Handle->new(
		fh => $fh, on_read => sub {
			my $fh = shift;

			my @ev = @_;
			while ($fh->{rbuf} =~ s/(.*?)\n//) {
				my $ev = $1;
				$ev =~ /\S/ and $machine->on_input($ev);
			};
		},
		on_eof => sub {
			$machine->on_input(undef);
			$machine = undef;
		},
		on_error => sub {
			# Avoid one SIGPIPE taking the server down
			warn "SOCKET ERROR: fatal=$_[1]: $_[2]";
			$machine->fh( undef );
			$machine->on_input(undef);
			$machine = undef;
		},
	);
	$machine->fh( $handle );
	# HACK initiate offline => offline trans.
	$machine->handle_event("bye");
	# NOTE machine and handle create a loop.
	# So need we to undef carefully to avoid leaks.
};

# Enter main loop...
my $cv = AnyEvent->condvar;
$SIG{INT} = sub {
	print "# Shutting down...";
	$_->on_input(undef) for My::SM::Handset->get_all;
	$cv->send;
};
$cv->recv;

