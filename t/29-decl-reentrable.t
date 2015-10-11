#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

my @retvals;
{
	package My::SM;
	use FSM::Arrow qw(:class);

	our $count;
	sm_init on_state_change => sub { $count++ }
		, on_return => sub { push @retvals, $_[1] };

	my $lock; # lock to ensure we're not recursing
	sm_state 1 => sub {
		$lock++ and die "Recusrion detected! Reentrability lost";
		$_[0]->handle_event("x");
		$lock = 0;
		2 => 22
	};
	sm_state 2 => sub { 3 => 333 };
	sm_state 3 => sub { 4 => 4444 };
	sm_state 4 => sub { 0 => 55555 }, final => 1;
};

my $sm = My::SM->new;

is (eval { $sm->handle_event("x"); }, 333, "Last return value avail directly" );
is ($@, '', "No recursion detected" );
is ($sm->state, 3, "1+1 state changes" );
is_deeply (\@retvals, [ 22, 333 ], "Return values retained in callback" );

$sm->state(1);
is (eval { $sm->handle_event("x", "x"); }, $retvals[-1], "Last value again");
is ($@, '', "No recursion detected" );
is ($sm->state, 4, "2+1 state changes" );

$sm->state(2);
$sm->handle_event("x");
is ($sm->state, 3, "1+0 state changes" );

my @err;
my @ret2;
{
	package My::Die;
	use FSM::Arrow qw(:class);

	sm_init on_error => sub { push @err, \@_ }
		, on_return => sub { push @ret2, $_[1] };
	sm_state 1 => sub {
		die $1 if /die\s+(\S.*)/;
		1 => $_;
	};
};

$sm = My::Die->new;
eval { $sm->handle_event( 1..5 ) };
is ($@, '', "No error as expected");
is_deeply (\@ret2, [ 1..5 ], "Retvals preserved" );
@ret2 = ();

eval { $sm->handle_event( "foo", "bar", "die here", "baz", "xxx" ); };
my $err = $@;
like ($err, qr(^here), "Exception as expected");
is_deeply (\@ret2, [ "foo", "bar" ], "Retvals until die preserved" )
	or note explain \@ret2;
is_deeply (\@err, [[ $sm, $err, ["baz", "xxx"] ]], "error cb args");

done_testing;
