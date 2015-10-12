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
use Data::Dumper;

# Always want latest & greatest FSM
use FindBin qw($Bin);
use lib "$Bin/../lib";

# State machine definitions
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

	use Class::XSAccessor accessors => {
		number => 'number', call => 'call', fh => 'fh' };

	sm_init strict => 1,
		on_event => event_maker_regex (
			class => "My::Event",
			regex => qr/(?<type>[a-z]\w*)(\s\D*(?<number>\d+))?/,
			undef => 'part',
		),
		on_state_change => sub {
			warn "    SM ". ($_[0]->number // '[offline]')
				. " $_[1] => $_[2] via '$_'; q=[@{$_[0]->sm_queue}]\n";
		},
		on_return => sub {
			my $self = shift;
			$self->reply( "OK: ", shift // '(silent)' );
		},
		on_error => sub {
			my $self = shift;
			$self->reply( "ERROR: ", $@ );
		};
	# events so far: join <number>, part;

	sm_state 'offline', on_enter => sub {
		my $self = shift;
		$self->sign_off;
		if (my $call = $self->call) {
			$call->handle_event( $self->mk_event("bye") );
		};
		$self->call( undef );
	};
	sm_transition join => 'online', handler => sub {
		my $self = shift;
		die "join requires number" unless $_->number;

		$self->sign_on($_->number);
		"Joined as ".$self->number;
	};
	sm_transition bye => 'offline';

	sm_state 'online', on_enter => sub {
		my $self = shift;
		if (my $call = $self->call) {
			$call->handle_event( $self->mk_event("bye") );
		};
		$self->call( undef );
	};
	sm_transition part => 'offline', handler => sub { "Gone offline" };
	sm_transition dial => 'calling', handler => sub {
		my $self = shift;
		die "dial requires number" unless $_->number;

		my $peer = $self->get_user( $_->number );
		die "No such user " . $_->number
			unless $peer;

		$self->call( $peer );
		$self->call->handle_event( $self->mk_event("ring") );
		"Calling ".$peer->number;
	};
	sm_transition ring => 'ringing', handler => sub {
		my $self = shift;
		$self->call( $_->peer );
		"Incoming call from ".$_->number.", accept?(y/n)";
	};
	sm_transition bye => 'online';

	sm_state 'calling';
	sm_transition part => 'offline', handler => sub { "Gone offline" };
	sm_transition y    => 'busy';
	sm_transition bye  => 'online',  handler => sub { "Call rejected" };
	sm_transition ring => 'calling', handler => sub {
		my $self = shift;
		my $peer = $self->get_user( $_->number );
		$peer and $peer->handle_event( $self->mk_event( "bye" ) );
	};

	sm_state 'ringing';
	sm_transition part => 'offline', handler => sub { "Gone offline" };
	sm_transition n    => 'online',  handler => sub {
		my $self = shift;
		my $peer = $self->get_user( $_->number );
		$peer and $peer->handle_event( $self->mk_event( "bye" ) );
		"Hangup";
	};
	sm_transition y    => 'busy',    handler => sub {
		my $self = shift;
		$self->call->handle_event( $self->mk_event( "y" ) );
		return;
	};

	sm_state 'busy', on_enter => sub {
		my $self = shift;
		$self->reply( "Talking to ".$self->call->number."..." );
	};
	sm_transition part => 'offline', handler => sub { "Gone offline" };
	sm_transition bye  => 'online',  handler => sub { "Hangup" };

	# Self check state definitions
	my $bad = __PACKAGE__->new->schema->validate();
	die "VIOLATIONS" . Data::Dumper::Dumper($bad) if $bad;

	# Simplify sending events to peer.
	sub mk_event {
		my ($self, $type) = @_;
		return My::Event->new(
			type => $type, number => $self->number, is_mt => 1 );
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
		$self->reply( ">> ", "number=", $self->number || 'off'
			, ", state=", $self->state
			, ($self->call ? ", call=". $self->call->number : ()));
	};

	sub reply {
		my $self = shift;
		my $msg = join "", @_;
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
			$machine->fh( undef );
			$machine->on_input(undef);
			$machine = undef;
		},
	);
	$machine->fh( $handle );
	# NOTE machine and handle create a loop.
	# So need we to undef carefully to avoid leaks.

	warn "    Peer joined($handle): $host:$port";
};

# Enter main loop...
my $cv = AnyEvent->condvar;
$SIG{INT} = sub {
	warn "Shutting down...";
	$_->on_input(undef) for My::SM::Handset->get_all;
	$cv->send;
};
$cv->recv;

