#!/usr/bin/env perl

# This is an example script for FSM::Arrow state machine library.
# It demonstrates a very simple state machine that triples a number
# represented by a binary string.

use strict;
use warnings;

# Always use the local version of FSM::Arrow
use FindBin qw($Bin);
use lib "$Bin/../lib";

# We'll define state machine via FSM::Arrow declarative interface.
# We must do it before first use (or use BEGIN block).
{
    package My::SM::Triple;          # This is going to be the SM instance
    use FSM::Arrow qw(:class);       # Import declarative primitives

                                     # Until first call to sm_*, this package
                                     # is just a normal package.

                                     # sm_init could precede sm_state
                                     # declaration in case we needed some
                                     # extra options.

    sm_state s0 => sub {             # First state is initial by default.
        $_ eq 0 and return s0 => 0;  # Specify transition(s):
        $_ eq 1 and return s1 => 1;  # (self, input) => (new_state, output)
        return fin => '';            # non-recognized string => stop here
    }, next => [ qw(s0 s1 fin) ];

                                     # At this point, current package
                                     # is a FSM::Arrow::Instance descendant
                                     # and has new(), state(), set_state(),
                                     # schema(), and handle_event() methods.

    sm_state s1 => sub {             # Second state goes...
        $_ eq 0 and return s0 => 1;
        $_ eq 1 and return s2 => 0;
        return fin => 1;
    }, next => [ qw(s0 s2 fin) ];    # Specify possible transitions.
                                     # If omitted, ANY next state is allowed.

    sm_state s2 => sub {
        $_ eq 0 and return s1 => 0;
        $_ eq 1 and return s2 => 1;
        return fin => "01";
    }, next => [ qw(s1 s2 fin) ];

    sm_state fin => sub {            # The final state
    }, final => 1;                   # The handler is empty, but it could
                                     # do something as well.

};                                   # The declaration ends here.

# Now fun...

print My::SM::Triple->new->schema->pretty_print, "\n";
                                     # Output state diagram
                                     # Rather clumsy one though

while (<>) {
    my $sm = My::SM::Triple->new;    # Instantiate the machine.
                                     # Machines are independent, even though
                                     # they share the meta-information.

    my @bits = /([01])/g;            # Get a bit string.
    @bits = reverse @bits;           # Smallest bits come first...

    my @output = map { $sm->handle_event($_) } @bits, "end of data";
                                     # Feed events (bits) to machine
                                     # The last event puts us into final state
                                     # and squeezes last bits from the machine

    print scalar reverse join "", @output;  # Print the results
    print "\n";
};


