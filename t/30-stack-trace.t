#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

$SIG{__DIE__} = \&Carp::confess;

my @trace;
{
	package My::SM1;
	use FSM::Arrow qw(:class);
	use Data::Dumper;

	sm_init  on_state_change => sub {
		$_-->0 && $_[0]->{other} && $_[0]->{other}->handle_event($_, $_)
	};
	sm_state flip => sub { "flop" };
	sm_state flop => sub { "flip" };

	sm_validate;

	package My::SM2;
	use FSM::Arrow qw(:class);

	sm_init on_state_change => sub {
		push @trace, FSM::Arrow->longmess( "HERE" );
	}, parent => 'My::SM1';
};

my @machines;
push @machines, My::SM2->new;
for (1..3) {
	push @machines, My::SM1->new( other => $machines[-1] );
};

is_deeply ([ map { $_->state } @machines], [ ("flip") x @machines ],
	 "All machines in initial state" );
$machines[-1]->handle_event(10);

foreach my $stack ($trace[0]) {
	my ($msg, @lines) = split /\n/, $stack;
	like $msg, qr(^HERE), "msg as expected";
	is (scalar @lines, 4, "Depth = 4" );
	like ($_, qr(My::SM.*flip.*handle_event), "Level ok" )
		for @lines;
};
foreach my $stack ($trace[1]) {
	my ($msg, @lines) = split /\n/, $stack;
	like $msg, qr(^HERE), "msg as expected";
	is (scalar @lines, 4, "Depth = 4" );
	like ($_, qr(My::SM.*fl[io]p.*handle_event), "Level ok" )
		for @lines;
};

note $trace[0];
note $trace[-1];

done_testing;
