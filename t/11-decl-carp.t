#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

{
	package My::Sm;
	use Carp;
	use FSM::Arrow qw(:class);

	sm_state one => sub {
		croak "This is a test";
	};
};

my $sm = My::Sm->new;
my $where;
eval {
	$where = __LINE__ + 1;
	$sm->handle_event(111); # this dies
};

my $err = $@;
note "Error was: ",$err;
ok ($err =~ /at (\S+) line (\d+)/, "Error came");
my ($file, $line) = ($1, $2);

is ($file, $0, "Error in current file");
is ($line, $where, "Error inside eval");

done_testing;
