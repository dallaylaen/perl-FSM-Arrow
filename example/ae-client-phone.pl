#!/usr/bin/env perl

use strict;
use warnings;
use AnyEvent::Strict;
use AnyEvent::Handle;

# Always want latest & greatest FSM
use FindBin qw($Bin);
use lib "$Bin/../lib";

my $DEBUG = 0;
my $VERBOSE = 1;
my $counter = 0;

{
	package My::Phone;
	use FSM::Arrow qw(:class);
	use Class::XSAccessor accessors => { number => 'number' };

	sm_init on_return => sub {
		my ($self, $reply) = @_;
		return unless $reply;
		$reply =~ s/\s*$/\n/s;
		my $fd = $self->{fh};
		$fd and $fd->push_write( $reply );
	};

	my %todo = (
		offline => [ "join X" ],
		online  => [ "part", ("dial Y") x 99, ],
		ringing => [ "n", ("y") x 9 ],
		busy    => [ "bye" ],
	);

	sm_state one_and_only => sub {
			my $self = shift;
			chomp;

			/\#\s*ERROR/ and print "[".$self->number."]$_\n"
				if $VERBOSE;
			/\!\s*(offline|online|ringing|busy)/ or return;

			my $state = $1;

			my $choice = $todo{ $1 };
			my $index = rand() * @$choice;
			my $reply = $choice->[ $index ];
			warn "index=$index, reply=$reply"
				if $DEBUG;

			$reply =~ s/X/ $self->number /ge;
			$reply =~ s/Y/ $self->other  /ge;

			$counter++;

			print "[".$self->number."] [$counter] got $state, reply: $reply\n"
				if $VERBOSE;

			return 0 => $reply;
		}, final => 1;

	my %users;
	sub other {
		my $self = shift;
		my @all = grep { $_ ne $self->number } keys %users;
		return $all[ rand() * @all ];
	};
	sub new {
		my ($class, %opt) = @_;
		$opt{number} or die "No number, sorry";
		$users{ $opt{number} } = $class->SUPER::new(%opt);
	};
}

my ($port, @num) = @ARGV;
if (!$port) {
	die "Usage: $0 <port> <num> ...";
};

my %uniq;
@num = grep { !$uniq{$_}++ } @num;

foreach (@num) {
	my $machine = My::Phone->new(number => $_);
	my $handle = AnyEvent::Handle->new(
		connect  =>  [ localhost => $port ],
		on_error => sub {
			print "[".$machine->number."] SOCKET ERROR: ".shift."\n";
			delete $machine->{fh}
		},
		on_read  => sub {
			my $fh = shift;
			while ( $fh->{rbuf} =~ s/([^\n]*)\n// ) {
				warn "[$machine->{number}] incoming: $1"
					if $DEBUG;
				$machine->handle_event($1);
			};
		},
		on_eof   => sub { delete $machine->{fh} },
	);
	die "Failed to connect to $port: $!"
		unless $handle;
	$machine->{fh} = $handle; # this leaks. Who cares? It's a test script
	$machine->handle_event( "@ offline" );
};

my $cv = AnyEvent->condvar;
# TODO configure delay
my $timer; $timer = AnyEvent->timer(
	after => 5, cb => sub { $cv->send; undef $timer; },
);

$SIG{INT} = sub {
	warn "Shutting down...";
	$cv->send;
};
$cv->recv;

print "Total: $counter\n";




