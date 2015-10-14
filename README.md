# FSM::Arrow

Event-driven state machine with declarative interface.

# Intended usage overview

1. Start out machine schema, declare states and transitions.

2. Create concrete machine. 
Multiple independent instances may exist at the same time.

3. Feed events to machine via `handle_event` method, receive replies if needed.
Both events and replies may be of any form.

Also save/load to/from storage may be added around step 3.
This may be useful in a daemon, web service, and so on.

# Features

* Package-based declarative interface (like Moose).

* Object-oriented interface for those who want more control.

* Inheritance. If needed, existing machine can be extended with 
extra or slightly different states.

* Compatibility. Can play along with Moose, Class::XSAccesor,
fields, and Class::StateMachine w/o breaking the machine.

* Strict transitions and typed events - for those who need it.

* Reenterable - a machine may send more events to other machines or itself.

* A lot of callbacks that can be hooked almost anywhere.

* Some inspection tools.

# Limitations

* Due to functional nature of handlers, exact transition map
cannot always be recreated.

* Despite all effort, line-by-line text parser examples keep looking like 
overengineered cryptic rubbish, which they probably are.

# Package content

## Modules under lib/

Module               | What it is for
---|---
FSM::Arrow           | Main module, contains machine schema class and
declarative interface which is available via `use FSM::Arrow qw(:class);`.
FSM::Arrow::Instance | Machine instance base class.
FSM::Arrow::Event    | Machine may digest events of any type 
(text strings, unblessed refs, custom objects). 
However, if strictly defined transitions are preferrable,
this class should be used.
FSM::Arrow::Util     | This class exports a few convenient callback generators.

## Examples under example/

File name               | What it demonstrates
---|---
bench.pl                | Run this file to determine relative speed of
different SM usage scenarios.
bit-string.pl           | Shows simple text-based machine.
This one has line-by-line commentary.
transition.pl           | Shows how typed transitions can be used.
This one has line-by-line commentary.
bit-string-accepting.pl | Shows how *accepting* states can be used. 
markdown.pl             | Reads markdown line by line.
runner.psgi             | PSGI stateful web-service example.
Needs plack server to run under.
ae-phone.pl             | AnyEvent-based reenterable state machine.
This one is huge actually.

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
