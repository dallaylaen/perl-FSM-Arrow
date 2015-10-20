#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

my $sm2 = My::SM::Child->new;

note "id = ", $sm2->sm_schema->to_string;

is ($sm2->state, "initial", "initial state");

$sm2->handle_event("foo");
is ($sm2->state, "initial", "still initial state");

$sm2->handle_event("bar");
is ($sm2->state, "final", "state changed");

$sm2->handle_event("baz");
is ($sm2->state, "real_final", "state changed again");

done_testing;

BEGIN {
package My::SM;
use FSM::Arrow qw(:class);

sm_state initial => sub { $_[1] =~ /bar/ and return "final" };
sm_state final => sub {};

package My::SM::Child;
use FSM::Arrow qw(:class);

sm_init parent => "My::SM";
sm_state final => sub { $_[1] =~ /baz/ and return "real_final" };
sm_state real_final => sub {};

};

