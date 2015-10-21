#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use FSM::Arrow::Event;

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

note "Try different event types...";
{
	package My::SM::Confess;
	use FSM::Arrow qw(:class);

	sm_init strict => 1;
	sm_state one_and_only => sub {
		die FSM::Arrow->longmess;
	}, final => 1;
	sm_validate;
};


my $sm = My::SM::Confess->new;
my $id = $sm->sm_to_string;

my $err;
eval { $sm->handle_event( undef ) };
$err = $@;
like $err, qr($id.*undef), "Stack trace w/undef";
note $err;

eval { $sm->handle_event( {} ) };
$err = $@;
like $err, qr($id.*HASH.0x), "Stack trace w/unblessed";
note $err;

eval { $sm->handle_event( bless {}, "My::Empty::Class" ) };
$err = $@;
like $err, qr($id.*My::Empty::Class=HASH.0x), "Stack trace w/blessed";
note $err;

eval { $sm->handle_event( FSM::Arrow::Event->new( type => "xxx" ) ) };
$err = $@;
like $err, qr($id.*FSM::Arrow::Event.*xxx), "Stack trace w/fsm event";
note $err;

done_testing;
