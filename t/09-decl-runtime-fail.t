#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

{
	package My::SM::Foo;
	use FSM::Arrow qw(:class);

	sm_state start => sub { return $_[1] }, next => [qw(run fun)];
	sm_state run   => sub { return $_[1] };
	sm_state fin   => sub { }; # final
};

my $sm = My::SM::Foo->new;

eval { $sm->handle_event( "fun" ) };
like $@, qr([Ii]llegal.*exist), "Nonexistent";
note $@;
is ($sm->state, "start", "still at the start");

eval { $sm->handle_event( "fin" ) };
like $@, qr([Ii]llegal.*forbid), "Forbidden";
note $@;
is ($sm->state, "start", "still at the start");

eval { $sm->handle_event( "run" ) };
ok (!$@, "finally normal call" );
is ($sm->state, "run", "not at the start");

done_testing;
