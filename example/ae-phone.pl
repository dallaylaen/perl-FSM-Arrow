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
# Phone call is also a state machine:
# [ ringing ]---->[ talking ]----->[ hangup ]
#       |                             ^
#       |    rejected                 |
#       +-----------------------------+
#

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
	package My::Event;
	use parent 'FSM::Arrow::Event';
	use Class::XSAccessor accessors => { is_mt => 'is_mt', number => 'number' };
	use overload '""' => \&as_string;

	sub as_string {
		my $self = shift;
		return join " ", $self->type, $self->number // ()
			, $self->is_mt ? "[mt]" : "[mo]";
	};
	sub peer {
		return My::SM::Handset->get_user( $_[0]->number );
	};

	package My::SM::Handset;
	use FSM::Arrow qw(:class);
	use FSM::Arrow::Util qw(:all);

	use Class::XSAccessor accessors => {
		number => 'number', call => 'call', fh => 'fh' };

	sub new {
		my $class = shift;
		return $class->SUPER::new( number => 0, @_);
	};

	sub on_input {
		my ($self, @raw) = @_;

		foreach (@raw) {
			my $ret;
			next if defined $_ and $_ !~ /\S/;
			if ( defined $_ and /^\s*check/ ) {
				$ret = sprintf "num=%s, state=%s"
					, $self->number || 'offline', $self->state;
			} else {
				$ret = eval { $self->handle_event($_) } // '(silent)';
			};
			$self->reply( ">> ", "number=", $self->number || 'off'
				, ", state=", $self->state
				, ($self->call ? ", call=". $self->call->number : ()));
		};
	};

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

		# TODO here will be new SM!
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
	sm_transition y    => 'busy',    handler => sub {
		"Talking to ".$_[0]->call->number };
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
		"Talking to ".$self->call->number;
	};

	sm_state 'busy';
	sm_transition part => 'offline', handler => sub { "Gone offline" };
	sm_transition bye  => 'online',  handler => sub { "Hangup" };

	# Self check state definitions
	my $bad = __PACKAGE__->new->schema->validate();
	die "VIOLATIONS" . Data::Dumper::Dumper($bad) if $bad;

	sub mk_event {
		my ($self, $type) = @_;
		return My::Event->new(
			type => $type, number => $self->number, is_mt => 1 );
	};

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

	package My::SM::Call;
	use FSM::Arrow qw(:class);
};
# end state machine definitions

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

# TODO real ae
# Main loop

# Listen

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
			warn "Error in socket: ".shift;
			$machine->fh( undef );
			$machine->on_input(undef);
			$machine = undef;
		},
	);
	$machine->fh( $handle );

	warn "    Peer joined($handle): $host:$port";
};

my $cv = AnyEvent->condvar;
$SIG{INT} = sub {
	warn "Shutting down...";
	$_->on_input(undef) for My::SM::Handset->get_all;
	$cv->send;
};
$cv->recv;

# Client joined => attach state machine to socket
# Data comes => parse events

