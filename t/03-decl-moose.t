#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

# Check that moose is available, skip gently otherwise
BEGIN {
	if (!eval { require Moose; 1 }) {
		plan skip_all => "Moose not found, skipping Moose test";
		exit;
	};
};

my $sm = My::Machine->new;

is ($sm->state, 'initial', "initial state holds");
is (ref $sm->schema, 'FSM::Arrow', "Schema ref correct");

my $ret = $sm->handle_event("don't go");
is ($ret, undef, "non mathing event => no retval");
is ($sm->state, 'initial', "non mathing event => no go");

$ret = $sm->handle_event("go now");
is ($ret, "now", "mathing event => retval");
is ($sm->state, 'final', "mathing event => state change");
is ($sm->last_state, 'initial', "last_state method check");

$ret = $sm->handle_event("go more");
is ($ret, 'initial', "final handler => last state");
is ($sm->state, 'final', "final handler => no state change");

done_testing;

BEGIN {
package My::Machine;

use Moose;
use FSM::Arrow qw(:class);

has last_state => is => "rw";

sm_state initial => sub {
	my ($self, $event) = @_;
	$self->last_state( $self->state );
	return (final => $1)
		if $event =~ /^go (.*)/i;
};

sm_state final => sub {
	my $self = shift;
	return 0 => $self->last_state;
};

}; # BEGIN
