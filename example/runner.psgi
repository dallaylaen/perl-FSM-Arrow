#!/usr/bin/env perl

use strict;
use warnings;
use Plack::Request;

use FindBin qw($Bin);
use lib "$Bin/../lib";

# FSM part
{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_init on_state_change => sub { warn "$_[0]->{session}: $_[1]=>$_[2]" };

	sm_state start => sub {
		my ($self, $ev) = @_;

		if ($ev->{run} and $ev->{run} > 0) {
			$self->{distance} = $ev->{run};
			return run => "Started!";
		};
	};

	sm_state run => sub {
		my ($self, $ev) = @_;

		if ($ev->{run} and $ev->{run} > 0) {
			$self->{distance} += $ev->{run};
		};

		if ($ev->{stop}) {
			return stop => "Stopped!";
		};
	};

	sm_state stop => sub {
	}, final => 1;

	sub status {
		my $self = shift;

		return "Session: $self->{session}\nState: $self->{state}\nDistance: "
			.($self->{distance} || 0);
	};

	# Storage part - sorry, no database here!
	my $incr;
	my %storage;
	sub load {
		my ($class, $session) = @_;

		return $class->new( session => ++$incr )
			unless $session;

		die "Session ont found: $session"
			unless exists $storage{$session};

		return $storage{$session};
	};

	sub save {
		my $self = shift;
		$storage{ $self->{session} } = $self;
	};
};

# PSGI part

my $app = sub {
	my $req = Plack::Request->new(shift);

	my $event = get_event ( $req )
		or return [ 404, [], [] ];
	my $session = get_session( $req );

	my $sm = My::SM->load( $session );

	my $reply = $sm->handle_event( $event );
	my $result = $reply ? "Result: $reply\n" : "";

	$sm->save;

	return [ 200, [ "Content-Type" => "text/plain" ], 
		[ $result, $sm->status ]]
};

sub get_event {
	my $req = shift;

	# return query parameters as a hash.
	# No duplicate values allowed.
	return unless $req->path eq '/';
	return {
		map { $_ => [ $req->param($_) ]->[-1] } $req->param,
	};
};

sub get_session {
	my $req = shift;
	return [ $req->param("session") ]->[-1];
};

$app = $app;
