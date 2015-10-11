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

	package My::SM::Handset;
	use FSM::Arrow qw(:class);
	use FSM::Arrow::Util qw(:all);

	use Class::XSAccessor accessors => { number => 'number', call => 'call' };

	sub new {
		my $class = shift;
		return $class->SUPER::new( number => 0, @_);
	};

	sm_init strict => 1,
		on_event => event_maker_regex (
			class => "My::Event",
			regex => qr/(?<type>[a-z]\w+)(\s\D*(?<number>\d+))?/,
			undef => 'part',
		),
		on_state_change => sub {
			warn "    SM ". $_[0]->number. " $_[1] => $_[2] via '$_'\n";
		};
	# events so far: join <number>, part;

	sm_state 'offline';
	sm_transition join => 'online', handler => sub {
		my $self = shift;
		die "join requires number" unless $_->number;

		$self->register($_->number);
		"Joined as ".$self->number;
	};

	sm_state 'online';
	sm_transition part => 'offline', handler => sub { "Gone offline" };
	sm_transition dial => 'calling', handler => sub {
		my $self = shift;
		die "dial requires number" unless $_->number;

		my $peer = $self->get_user( $_->number );
		die "Nu such user " . $_->number
			unless $peer;

		# TODO here will be new SM!
		$self->call( $peer );
		"Calling ".$peer->number;
	};

	sm_state 'calling';
	sm_transition part => 'offline', handler => sub { "Gone offline" };

	# Self check state definitions
	my $bad = __PACKAGE__->new->schema->validate();
	die "VIOLATIONS" . Data::Dumper::Dumper($bad) if $bad;

	our %users;
	sub register {
		my ($self, $number) = @_;
		die "Number $number already in use"
			if $users{$number};

		$self->number( $number );
		$users{$number} = $self;
		return $self;
	};
	sub part {
		my $self = shift;
		my $number = delete $self->{number};
		delete $users{$number} if $number;
		$number;
	};
	sub get_user {
		my ($class, $number) = @_;
		return $users{$number};
	};

	package My::SM::Call;
	use FSM::Arrow qw(:class);
};


my $sm = My::SM::Handset->new;
while (<>) {
	my $ret = eval { $sm->handle_event($_) } // "(silent)";
	if (my $err = $@) {
		print "ERROR: $err\n";
	} else {
		print "OK: $ret\n";
	};
};


# TODO real ae
# Main loop

# Listen

# Client joined => attach state machine to socket
# Data comes => parse events

