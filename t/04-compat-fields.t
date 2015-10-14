#!/usr/bin/env perl

# Test that declarative interface is consistent with fields.

use strict;
use warnings;
use Test::More;

BEGIN { $ENV{FSM_ARROW_NOXS} = 1 };

my $sm = My::Machine->new;

is ($sm->state, 'initial', "initial state holds");
is (ref $sm->sm_schema, 'FSM::Arrow', "Schema ref correct");

my $ret = $sm->handle_event("don't go");
is ($ret, undef, "non mathing event => no retval");
is ($sm->state, 'initial', "non mathing event => no go");

$ret = $sm->handle_event("go now");
is ($ret, "now", "mathing event => retval");
is ($sm->state, 'final', "mathing event => state change");

$ret = $sm->handle_event("go more");
is ($ret, undef, "empty handler => no retval");
is ($sm->state, 'final', "empty handler => no state change");

done_testing;

BEGIN {
package My::Machine;

use base qw(FSM::Arrow::Instance);
use fields qw(weird_user_data);
use FSM::Arrow qw(:class);

sub new {
	fields::new(shift)->sm_on_construction;
};

sm_state initial => sub {
	my ($self, $event) = @_;
	return (final => $1)
		if $event =~ /^go (.*)/i;
};

sm_state final => sub {
};

}; # BEGIN
