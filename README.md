# FSM::Arrow

Event-driven state machine with declarative interface.

# Intended usage

1. Declare states as "name" => sub { HANDLER };
Handler returns next state when called.

2. Create machine. Multiple independent instances may exist.

3. Feed events to machine, receive replies if needed.
Both events and replies may be of any form.

Also save/load to/from storage may be added around step 3.
This may be useful in a daemon, web service, and so on.

# Features

* Package-based declarative interface (like Moose).

* Object-oriented interface for those who want more control.

* Inheritance. If needed, existing machine can be extended with 
extra or slightly different states.

* Compatibility. Instance class may be enhanced via Moose, Class::XSAccesor,
fields w/o breaking the machine.

* Optional transition restrictions (list of possible next states, final state).

* Inspection tools and state change callbacks.

# Limitations

* Due to functional nature of handlers, exact transition map
cannot be recreated.

* Despite all effort, line-by-line text parser examples keep looking like 
overengineered cryptic rubbish, which they probably are.

# Installation

Until this module is released onto CPAN, this standard command sequence
can be used:

    perl Makefile.PL
    make
    make test
    sudo make install

# Support and documentation

For detailed guide, see

    perldoc FSM::Arrow

Also the examples/ directory indeed contains some examples.

Please report bugs to https://github.com/dallaylaen/perl-FSM-Arrow/issues

# Copyright and license

Copyright (c) 2015 Konstantin S. Uvarin <khedin@gmail.com>

This program is free software and can be distributed on the same terms
as Perl itself.
