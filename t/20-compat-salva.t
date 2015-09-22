#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

BEGIN {
	if (! eval { require Class::StateMachine; 1; }) {
		plan skip_all => "Class::StateMachine not available, skip test";
		exit;
	};
};

{
	package My::SM;

	use base qw(Class::StateMachine);
	use FSM::Arrow qw(:class);

	sm_state one => sub { two => 1 };
	sm_state two => sub { one => 2 };

	no warnings 'redefine';
	sub new {
		my $class = shift;
		my $self = $class->SUPER::new(@_);
		Class::StateMachine::bless( $self, $class, $self->{state} );
	};
	sub who : OnState("one") { return 1 };
	sub who : OnState("two") { return 2 };
};

my $sm = My::SM->new;

is $sm->who, 1, "state 1";

$sm->handle_event(42);
is $sm->who, 2, "state 2";

$sm->handle_event(42);
is $sm->who, 1, "state 1";

done_testing;

