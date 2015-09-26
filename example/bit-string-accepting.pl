#!/usr/bin/env perl

# This demonstrates usage of accepting states
# Input:  a string of [01]
# output: "Divisible by 3" | 0

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

{
	package My::SM::Div3;
	use FSM::Arrow qw(:class);

	sm_init on_state_change => sub { warn "\t$_[1] + $_ => $_[2]\n" };
	# states: bit(odd, even) x residue(0, 1, 2)

	sm_state odd_0 => sub {
		return $_ ? "even_1" : "even_0";
	}, accepting => "Divisible by 3";
	sm_state odd_1 => sub {
		return $_ ? "even_2" : "even_1";
	};
	sm_state odd_2 => sub {
		return $_ ? "even_0" : "even_2";
	};
	sm_state even_0 => sub {
		return $_ ? "odd_2"  : "odd_0";
	}, accepting => "Divisible by 3";
	sm_state even_1 => sub {
		return $_ ? "odd_0"  : "odd_1";
	};
	sm_state even_2 => sub {
		return $_ ? "odd_1"  : "odd_2";
	};
};

while (<>) {
	my @bits = /([01])/g;
	my $sm = My::SM::Div3->new;
	$sm->handle_event($_) for @bits;
	print $sm->accepting, "\n";
};
