#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use FSM::Arrow::Event;

{
	package My::SM;
	use Carp;
	use FSM::Arrow qw(:class);

	our @follow;

	sm_state one => sub { croak "No handler allowed" }, next => [];
	sm_transition 0 => 'two';
	sm_transition 1 => 'three', on_follow => sub { push @follow, \@_ };

	sm_state two => sub { croak "No handler allowed" }, next => [];
	sm_transition 0 => 'two';
	sm_transition 1 => 'one', handler => sub { "return" };

	sm_state three => sub {}, final => 1, accepting => 1;
};

my $sm = My::SM->new;

note $sm->schema->pretty_print;

# note "schema = ",explain $sm->schema;

eval {
	$sm->handle_event(1);
};
my $err = $@;
like ($err, qr(No handler allowed), "No bareword events, plz");
eval {
	$sm->handle_event(make_event("foo"));
};
$err = $@;
like ($err, qr(No handler allowed), "No unexpected transitions");

my $ev = make_event(0);
# note "event = ", explain $ev;

$sm->handle_event($ev);
is ($sm->state, "two", "State change via transition");

$ev = make_event(1);
is ($sm->handle_event($ev), "return", "event_handler works as exp.");

is_deeply( \@My::SM::follow, [], "on_follow not called" );
$sm->handle_event($ev);
is_deeply( \@My::SM::follow, [[ $sm, one=>'three', $ev ]],
	"on_follow was called");
is ($sm->state, "three", "State change via transition");

# note "Testing derived machine";
{
	package My::SM::Better;
	use Carp;
	use FSM::Arrow qw(:class);

	sm_init parent => 'My::SM';

	sm_state two => sub { croak "No handler allowed" };
	sm_transition 3 => 'three';
}

my $sm2 = My::SM::Better->new;
$sm2->handle_event( make_event(0) );
is( $sm2->state, "two", "State changed in derived machine" );
eval {
	$sm2->handle_event( make_event(1) );
};
$err = $@;
like ($err, qr(No handler allowed), "No unexpected transitions");

# Test that cloning still works after sm_transition
# NOTE no tests below this one - structure is BROKEN

# Make clone
my $orig = $sm->schema;
my $clone = $orig->clone;

# Remove known difference
delete $orig->{last_added_state};
delete $orig->{state_lock};
delete $orig->{id};
delete $clone->{id};

# Compare!
is_deeply( $clone, $orig, "Clone still works" )
	or do {
		diag "old schema = ", explain $orig;
		diag "new schema = ", explain $clone;
	};

done_testing;

sub make_event {
	my $str = shift;
	return FSM::Arrow::Event->new( type => [$str =~ /(\d+)/]->[0] );
};