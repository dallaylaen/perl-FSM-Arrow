#!/usr/bin/env perl

# Check for ridiculous bad use cases

use strict;
use warnings;
use Test::More;

my @warn;
$SIG{__WARN__} = sub { push @warn, shift };

{
	package My::SM;
	use FSM::Arrow qw(:class);

	sm_state one => sub { "two" };
	sm_state two => sub {}, final => 1;
}

eval {
	My::SM->new("xxx");
};
like $@, qr/[Oo]dd.*new/, "exception on bad new() usage";

use FSM::Arrow::Instance;
eval {
	FSM::Arrow::Instance->new;
};
like $@, qr/FSM::Arrow.*constructor.*decl/,
	"exception on missing new() params";

ok (!@warn, "No warnings emitted");
diag "WARNING: $_" for @warn;

{
	package My::BadSM;
	use FSM::Arrow qw(:class);
	use Test::More;

	eval {
		sm_init foo => 1;
	};
	like $@, qr(unexpected), "new: unexpected param = no go";
	eval {
		sm_state start => sub {}, foo => 1;
	};
	like $@, qr(unexpected), "add_state: unexpected param = no go";

	sm_state real_start => sub {};
	eval {
		sm_transition [] => 'finish', foo => 1;
	};
	like $@, qr(unexpected), "add_transition: unexpected param = no go";
};

done_testing;
