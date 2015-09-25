package FSM::Arrow;

use 5.006;
use strict;
use warnings;

=head1 NAME

FSM::Arrow - Declarative inheritable generic state machine.

=cut

our $VERSION = 0.0403;

=head1 DESCRIPTION

This module provides a state machine intended for web services
and asynchronous apps.

The usage is as follows:

=over

=item * Define state machine states and transitions
as (state_name, event_handler(), %options) tuples
using object-oriented or declarative interface;

The handler interface can be described as following pseudocode:

    my ($next_state, $return_value) = CODE->($machine_instance, $event);

Event format and content is at the users discretion - those may be special
objects or plain strings (say one wants a parser).

Same goes for return values.

=item * Create a state object from that definition. Multiple independent
instances of the same machine may exist;

=item * Feed events to machine via handle_event() method,
which will switch machine's state and return arbitrary data.

=back

=head1 DECLARATIVE MOOSE-LIKE INTERFACE

	package My::State::Machine;

	use FSM::Arrow qw(:class);

	sm_state initial => sub {
		my ($self, $event) = @_;

		return final => 'Here we go'
			if $event =~ bar;
	};

	sm_state final => sub {};

	package My::State::Machine::Better;

	use FSM::Arrow qw(:class);

	sm_init parent => 'My::State::Machine';

	sm_state final => sub { '', "This state is final" };

	# later in calling code
	use My::State::Machine;

	my $sm = My::State::Machine->new;

	print $sm->state; # initial

	$sm->handle_event( "foo" ); # returns undef, state = initial
	$sm->handle_event( "bar" ); # returns "Here we go", state = final
	$sm->handle_event( "baz" ); # returns undef, state = final

	$sm->isa("FSM::Arrow::Instance"); # true
	$sm->schema; # returns a FSM::Arrow object

=head1 USAGE

A statement in one's package:

    use FSM::Arrow qw(:class);

 - would import static prototyped functions sm_init and sm_state into
the calling package.

On the first usage of either, the following happens:

=over

=item * The calling package becomes descendant of FSM::Arrow::Instance;

=item * The calling package gets C<schema> method which returns
a FSM::Arrow object;

=item * The calling package inherits C<state> and C<new> methods
with obvious semantics (see CONTRACT below);

=item * The calling package also inherits C<handle_event( $event )> method
which is the whole point of this.

=back

=head2 handle_event( $event )

Feeds event to the current state's handler. If the handler returns
a transition, state is undated accordingly. Return value is also determined
by handler.

See C<sm_state> below.

=cut

use Carp;
use Storable qw(dclone); # would rather use Clone, but is it ubiquitous?
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(sm_state sm_init);
our %EXPORT_TAGS = ( class => [ 'sm_state', 'sm_init' ] );

our @CARP_NOT = qw(FSM::Arrow::Instance);

use FSM::Arrow::Instance;

=head2 sm_init %options

Initialize state machine schema with %options. See new() below.
This call may be omitted, unless options are really needed.

options may include:

=over

=item * initial_state => 'state name'.
If not given, the first sm_state definition is used for initial state.

=item * parent => 'Class::Name'.
If given, class is loaded just like use parent (...) would do.
After that, state definitions are copied into current class.

B<NOTE> Parent class MUST also be set up using FSM::Arrow declarative interface.

B<NOTE> Only one parent may be supplied.

=item * on_state_change => CODE($instance, $old, $new, $event)

Callback that is called upon EVERY state transition.
The signature is exactly that of on_enter, on_leave
in the sm_state section below.

May be useful for debugging, logging etc.

B<NOTE> Exception in this callback would cancel the transition.

=back

sm_init MUST be called no more than once, and before ANY sm_state calls.

=cut

our %sm_schema;

sub sm_init (@) { ## no critic
	croak "sm_init: FATAL: Odd number of arguments"
		if @_%2;

	my $caller = caller;

	croak "sm_init: FATAL: SM schema already initialized"
		if exists $sm_schema{$caller};

	my %args = @_;
	if ($args{parent} and !ref $args{parent}) {
		my $parent = $args{parent};

		# try loading parent if schema not present
		if (!exists $sm_schema{$parent}) {
			my $file = $parent;
			$file =~ s{::}{/}g;
			$file .= ".pm";
			require $file;

			croak "sm_init: parent $parent is not FSM::Arrow a state machine"
				unless exists $sm_schema{$parent};
		};

		$args{parent} = $sm_schema{$parent};
		if (!$caller->isa($parent)) {
			no strict 'refs'; ## no critic
			push @{ $caller.'::ISA' }, $parent;
		}
	};

	__PACKAGE__->_sm_init_schema($caller, %args);
};

=head2 sm_state 'name' => HANDLER($self, $event), %options;

Define a new state.

'name' MUST be a unique true string.

HANDLER MUST be a subroutine which accepts two parameters:
state machine instance and incoming event.

HANDLER MUST return next state name followed by an arbitrary return value,
both of which MAY be omitted.

Next state MUST be either a false value, which means no change,
or a valid state name added via sm_state as well.

Whenever handle_event is called, it passes its argument to HANDLER
and returns the second returned value.

%options may include:

=over

=item * initial => 1 - force this state to be initial.

B<NOTE> Uniqueness of initial declaration is not checked,
but this may change in the future.
For now, the LAST such option overrides the previous ones.

=item * final => 1 - this state is final.

Any outgoing transitions will be ignored, however,
second return value from handler will still be returned by handle_event.

=item * next => [ state, state ... ]

Whitelist possible transitions. Attempt to violate will die.
Not allowed in a final state.

=item * on_enter => sub->( $self, $old_state, $new_state, $event )

Whenever state is entered via handle_event, call this sub.
If it dies, the state is NOT entered.

B<NOTE> This happens immediately after processing the previous state.
Otherwise this code could have been just placed in the beginning of the
HANDLER itself.

B<NOTE> $self->state is still the old state during execution of this callback.

B<NOTE> on_enter is NOT called when new() or state(...) is called.

=item * on_leave => sub->( $self, $old_state, $new_state, $event )

Whenever state is left, call this sub.
If it dies, cancel the transition.
Not allowed in final state.

B<NOTE> on_leave is ALWAYS called before on_enter.

B<NOTE> Returning a false value from HANDLER will not
trigger on_enter and on_leave,
however, returning current state will trigger both.

=back

During execution of HANDLER, on_enter, and on_leave, $_ is localized
and represents the event being processed.

B<NOTE> even though HANDLER looks a lot like a method,
no method with such name is actually created and it is safe to have one.
See CONTRACT below.

See also add_state() below.

=cut

sub sm_state ($$@) { ## no critic
	croak "sm_state: FATAL: Odd number of arguments"
		if @_%2;
	my ($name, $handler, @options) = @_;

	my $caller = caller;

	my $schema = __PACKAGE__->_sm_init_schema($caller);
	$schema->add_state( $name => $handler, @options );
};

sub _sm_init_schema {
	my ($class, $caller, @args) = @_;

	# memoize
	return $sm_schema{ $caller } ||= do {
		my $sm = $class->new( instance_class => $caller, @args );

		# Now magic - alter target package
		no strict 'refs';         ## no critic

		push @{ $caller.'::'.'ISA' }, 'FSM::Arrow::Instance';

		$sm;
	};
};

=head1 CONTRACT

A state machine instance class, or B<$instance> hereafter,
MUST exhibit the following properties for the machine to work correctly.

C<$instance> must be a descendant of L<FSM::Arrow::Instance> class.
This is enforced by the first use of sm_init or sm_state.

C<$instance->scheme()> method must be present.
Its return value must be the same C<FSM::Arrow> object
throughout the instance lifetime.

C<$instance->state(...)> accessor must be present.

When given no argument, it must return the last value given to it,
or C<$instance->scheme->initial_state> if none available.

$instance->handle_event($event) method must be left intact, or call
C<$instance->scheme->handle_event($instance, $event)>
at some point if redefined.

Additionally, if used with OO interface (see below), the constructor
must be named C<new()>, and must accept C<new(schema => $object)> parameters
resulting in that very object being returned by C<scheme> method.

All of these methods are implemented in exactly that way
in FSM::Arrow::Instance under assumption
that self is a blessed hash and keys C<state> and C<schema> are available.

If Moose is used, no additional care has to be taken (unless these methods
are overridden).

If C<use fields> is used, adding C<state> and C<schema> to the fields list
is required.

The following function can be used to fetch exactly th FSM::Arrow instance
used by sm_init/sm_state.

=head2 get_default_sm( $class )

Return state machine set up via declarative interface.

Can be called as both FSM::Arrow::get_default_sm and
FSM::Arrow->get_default_sm - it only cares about last argument.

=cut

sub get_default_sm {
	return $sm_schema{ $_[-1] };
};

=head1 OBJECT-ORIENTED INTERFACE

One may use FSM::Arrow directly, if needed
- that is, create state machine schemas, spawn instances, and process events.

Declarative interface is actually syntactic sugar over this one.

The state machine is separated into
B<schema> which carries state definitions and metadata
and B<instance> which stores schema reference and the current state.

A custom instance class may be defined,
provided that it follows CONTRACT (see above).

=head1 SYNOPSIS

    use FSM::Arrow;

    my $schema = FSM::Arrow->new( instance_class => 'My::Context' );
	$schema->add_state( "name" => sub { ... }, next => [ 'more', 'states' ] );
	# ... more or the same

	# much later
	my $instance = $schema->spawn;
	while (<>) {
		my $reply = $instance->handle_event($_);
		print "$reply\n";
		last if $instance->is_final;
	};

	package My::Context;
	use parent qw(FSM::Arrow::Instance);

=head1 METHODS

=cut

=head2 new( %args )

Args may include:

=over

=item * instance_class - the class the machine instances belong to.
Default is FSM::Arrow::Instance;

=item * initial_state - inintial machine state.
Default is the first state defined by add_state();

=back

=cut

sub new {
	my ($class, %args) = @_;

	croak __PACKAGE__."->new: on_state_change must be a subroutine"
		unless _is_sub($args{on_state_change});
	if (my $parent = delete $args{parent}) {
		return $parent->clone( %args );
	};

	$args{instance_class} ||= 'FSM::Arrow::Instance';

	my $self = bless {
		instance_class   => $args{instance_class},
		initial_state    => $args{initial_state},
		on_state_change  => $args{on_state_change},
		id               => $args{id},
	}, $class;

	$self->{id} ||= $self->generate_id;
	return $self;
};

=head2 clone( %options )

Create a copy of SM schema object.

Cloned state handlers can then be overridden by add_state.

Options are the same as for new(), except for parent which is forbidden.

=cut

sub clone {
	my ($self, %args) = @_;

	$self->_croak("parent option given to clone()")
		if exists $args{parent};

	my $new = (ref $self)->new(
		instance_class   => $self->instance_class,
		initial_state    => $self->initial_state,
		on_state_change  => $self->{on_state_change},
		%args,
	);

	$new->{$_} = _shallow_copy($self->{$_})
		for qw(state_handler on_enter on_leave final_state);
	$new->{$_} = dclone($self->{$_})
		for qw(transitions);

	return $new;
};

sub _shallow_copy {
	my $hash = shift;
	return ref $hash ? { %$hash } : $hash;
};

=head2 id()

Returns state machine schema unique identifier.

Unless given explicitly to new(), defaults to generate_id() output.

=cut

sub id {
	return $_[0]->{id};
};

=head2 initial_state()

Returns initial state. Defaults to first added state,
but may be overridden in constructor.

=cut

sub initial_state {
	return $_[0]->{initial_state};
};

=head2 instance_class()

=cut

sub instance_class {
	return $_[0]->{instance_class};
};

=head2 add_state( 'name' => HANDLER($instance, $event), %options )

Define a new state.

'name' MUST be a unique true string, HANDLER MUST be a subroutine.

CODE MUST return next state name followed by an arbitrary return value, both
of which may be omitted.

See C<sm_state> above for detailed description of name, HANDLER,
and available options.

Self is returned (so this method can be chained).

Trying to add a state more than once would cause exception,
UNLESS this is FIRST redefinition of an existing state
in a clone of another machine.

=cut

sub add_state {
	croak __PACKAGE__."->add_state: odd number of arguments"
		unless @_%2;
	my ($self, $name, $code, %args) = @_;

	# check input thoroughly
	croak __PACKAGE__."->add_state: state name must be true string"
		unless $name and !ref $name;
	# TODO code should allow string 'FINAL' for final states
	croak __PACKAGE__."->add_state: handler must be a subroutine"
		unless $code and _is_sub($code);
	croak __PACKAGE__."->add_state: state $name already defined"
		if $self->{state_lock}{ $name } and !$args{override};
	_is_sub( $args{$_} )
		or croak __PACKAGE__."->add_state: $_ callback must be a subroutine"
		for qw(on_enter on_leave);
	croak __PACKAGE__."->add_state: next must be array of true strings"
		if( $args{next}
			&& ( ref $args{next} ne 'ARRAY'
			|| grep { !$_ || ref $_ } @{ $args{next} }));

	# final state has some restrictions...
	if ($args{final}) {
		my @extra = grep { defined $args{$_} } qw(on_leave next);
		croak __PACKAGE__
			."->add_state: argument(s) @extra forbidden in a final state"
				if @extra;
	};


	# now update self
	# NOTE we MUST override ALL options
	# just in case we're redefining an older state.
	# Except for callbacks which may stay.
	$self->{state_handler}{$name} = $code;
	$self->{initial_state} = $name
		if $args{initial} or !defined $self->{initial_state};
	$self->{final_state}{$name} = $args{final} ? 1 : 0;
	$self->{transitions}{ $name } = $args{next}
		? _array_to_hash( $args{next} )
		: undef;
	exists $args{$_} and $self->{$_}{ $name } = $args{$_}
		for qw(on_enter on_leave);

	# Lock state. Note: this is released when object is cloned
	#    to allow state overrides
	$self->{state_lock}{$name}++;

	return $self;
};

# return true for undef OR anything callable
sub _is_sub {
	my $ref = shift;

	return (!defined $ref || (ref $ref && UNIVERSAL::isa( $ref, 'CODE' )));
};

# reverse of keys
sub _array_to_hash {
	my $list = shift;
	my %hash;
	$hash{$_} = 1 for @$list;
	\%hash;
};

=head2 spawn()

Returns a new machine instance.

state() is set to initial_state. schema() is set to self.

=cut

sub spawn {
	my $self = shift;

	my $instance = $self->{instance_class}->new( schema => $self );
	return $instance;
};

=head2 handle_event( $instance, $event )

Process event based on $instance->state and state definition.
Adjust state accordingly.

Return is determined by state handler's second optional return value.
See sm_state above for HANDLER discussion.

This is normally called as $instance->handle_event( $event ) and not directly.

=cut

sub handle_event {
	# The same in NORMAL notation:
	# my ($self, $instance, $event) = @_;
	# local $_ = $event;
	# Premature optimization, thats it...
	(my ($self, $instance), local $_) = @_;

	my $old_state = $instance->state;
	my $code = $self->{state_handler}{ $old_state };

	my ($new_state, $ret) = $code->( $instance, $_ );

	if ($new_state and !$self->{final_state}{$old_state}) {
		$self->_croak("Illegal transition '$old_state'->'$new_state'(nonexistent)")
			unless exists $self->{state_handler}{ $new_state };
		$self->_croak("Illegal transition '$old_state'->'$new_state'(forbidden)")
			if $self->{transitions}{ $old_state }
				and !$self->{transitions}{ $old_state }{ $new_state };
		# TODO check legal transitions if available
		$self->{on_leave}{$old_state}->(
				$instance, $old_state, $new_state, $_ )
			if $self->{on_leave}{$old_state};
		$self->{on_enter}{$new_state}->(
				$instance, $old_state, $new_state, $_ )
			if $self->{on_enter}{$new_state};
		$self->{on_state_change}->(
				$instance, $old_state, $new_state, $_ )
			if $self->{on_state_change};
		$instance->state( $new_state );
	};

	return $ret;
};

sub _croak {
	croak $_[0]->id.": $_[1]";
};

=head2 is_final( $state_name )

Tells whether $state_name is a final state in the current schema.

Invalid states are ignored, i.e. no exception. This may change in the future.

=cut

sub is_final {
	my ($self, $state) = @_;

	return 1 if $self->{final_state}{$state};
	# $self->_croak("Invalid state $state")
	#     unless $self->{states}{$state};
	return 0;
};

=head2 generate_id()

Returns an unique id containing at least schema and instance class refs.

B<NOTE> This is normally NOT called directly.

=cut

my $id;
sub generate_id {
	my $self = shift;

	my $schema = ref $self;
	my $instance = $self->{instance_class};

	return "$schema<$instance>#".++$id;
};

=head1 DEBUGGING/INSPECTION PRIMITIVES

=head2 list_states

List all defined states. initial_state is guaranteed to come first.

=head2 get_state( $name )

Get hashref with state properties. State can be recreated as

    $sm->add_state( delete $ref->{name}, delete $ref->{handler}, %$ref );

See C<sm_state> above.

Dies if no such state exists.

=cut

sub list_states {
	my $self = shift;

	my $first = $self->initial_state;
	return $first, grep { $_ ne $first } keys %{ $self->{state_handler} };
};

sub get_state {
	my ($self, $name) = @_;

	$self->_croak("get_state(): No state named '$name'")
		unless exists $self->{state_handler}{ $name };

	my $next = $self->{transitions}{ $name };
	$next = $next ? [ keys %$next ] : undef;

	return {
		name       => $name,
		handler    => $self->{state_handler}{ $name },
		final      => $self->{final_state}{ $name } ? 1 : 0,
		next       => $next,
		on_enter   => $self->{on_enter}{$name},
		on_leave   => $self->{on_leave}{$name},
		initial    => $self->initial_state eq $name ? 1 : 0,
	};
};

=head2 pretty_print

B<EXPERIMENTAL>

Display state machine in human-readable way.
This will change over time.

Returns a multi-line string.

=cut

sub pretty_print {
	my $self = shift;

	my @states = $self->list_states;
	return join "\n", map {
		join "",
			$_->{initial} ? "*" : " ",
			$_->{name},
			$_->{final}   ? "[x]" :
				$_->{next}    ? "->[@{$_->{next}}]" : "->*",
	} map {
		$self->get_state( $_ );
	} @states;
};

=head1 AUTHOR

Konstantin S. Uvarin, C<< <khedin at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-fsm-arrow at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=FSM-Arrow>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc FSM::Arrow


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=FSM-Arrow>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/FSM-Arrow>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/FSM-Arrow>

=item * Search CPAN

L<http://search.cpan.org/dist/FSM-Arrow/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2015 Konstantin S. Uvarin.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of FSM::Arrow
