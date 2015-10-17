package FSM::Arrow;

use 5.006;
use strict;
use warnings;

=head1 NAME

FSM::Arrow - Declarative inheritable generic state machine.

=cut

our $VERSION = 0.0701;

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
	$sm->sm_schema; # returns a FSM::Arrow object

=head1 USAGE

A statement in one's package:

    use FSM::Arrow qw(:class);

 - would import static prototyped functions sm_init and sm_state into
the calling package.

On the first usage of either, the following happens:

=over

=item * The calling package becomes descendant of FSM::Arrow::Instance;

=item * The calling package gets C<sm_schema> method which returns
a FSM::Arrow object;

=item * The calling package inherits C<state> and C<new> methods
with obvious semantics (see CONTRACT below);

=item * The calling package also inherits C<handle_event( $event )> method
which is the whole point of this.

=back

=head3 handle_event( $event )

Feeds event to the current state's handler. If the handler returns
a transition, state is undated accordingly. Return value is also determined
by handler.

See C<sm_state> below.

=cut

## no critic (RequireArgUnpacking) # we'll use A LOT of @_, sorry
use Carp;
use Scalar::Util qw(blessed);
use base 'Exporter';
my @CLASS = qw( sm_init sm_state sm_transition sm_validate );
our @EXPORT_OK = @CLASS;
our %EXPORT_TAGS = ( class => \@CLASS );

our @CARP_NOT = qw(FSM::Arrow::Instance);

use FSM::Arrow::Instance;

# Use XS Accessors if available, for speed & glory!
# Normal accessors are still present and work the same (but slower).
my $can_xs = !$ENV{FSM_ARROW_NOXS} && eval { require Class::XSAccessor; 1 };
if ($can_xs) {
	Class::XSAccessor->import(
		replace => 1,
		getters => {
			initial_state  => 'initial_state',
			instance_class => 'instance_class',
		},
	);
};

=head3 sm_init %options

Initialize state machine sm_schema with %options. See new() below.
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

=item * on_event => CODE($event)

If set, incoming events will be replaced by whatever is returned by CODE
in list context.
C<return ();> or C<return;> by CODE will prevent event from getting to SM.

This may be useful if you want to receive some raw data and change it to
L<FSM::Arrow::Event>. See also EVENT GENERATORS in L<FSM::Arrow::Util>.

=item * on_state_change => CODE($instance, $old, $new, $event)

Callback that is called upon EVERY state transition.
The signature is exactly that of on_enter, on_leave
in the sm_state section below.

May be useful for debugging, logging etc.

=item * on_return => CODE( $instance, $return_value_from_handler )

Callback that is called before setting new state and returning a value.
This may be useful when events are queued.
In such case only the LAST value returned by handler is retained.

=item * on_error => CODE( $instance, $exception, $leftover_event_queue )

Callback that is called when handler or ANY of other numerous callbacks die.
It may be used to restore the machine back to a consistent state,
or to provide some diagnostics to the user.

After execution of this callback, $@ gets rethrown.
This may change in the future.

B<NOTE> One may try to feed queue to handle_event,
but it may cause a deep recursion for now:

    on_error => sub {
        my ($self, $err, $queue) = @_;
        $self->handle_event( @$queue ); # possible, but fishy
    },

=back

B<NOTE> Exception in ANY of these callbacks would cancel the transition.

sm_init MUST be called no more than once, and before ANY sm_state calls.

=cut

my %sm_schema;

sub sm_init (@) { ## no critic (ProhibitSubroutinePrototypes)
	croak "sm_init: FATAL: Odd number of arguments"
		if @_%2;

	my $caller = caller;

	croak "sm_init: FATAL: SM sm_schema already initialized"
		if exists $sm_schema{$caller};

	my %args = @_;
	if ($args{parent} && !ref $args{parent}) {
		my $parent = $args{parent};

		# try loading parent if sm_schema not present
		if (!exists $sm_schema{$parent}) {
			my $file = $parent;
			$file =~ s{::}{/}gxs;
			$file .= ".pm";
			require $file;

			croak "sm_init: parent $parent is not FSM::Arrow a state machine"
				unless exists $sm_schema{$parent};
		};

		$args{parent} = $sm_schema{$parent};
		if (!$caller->isa($parent)) {
			no strict 'refs'; ## no critic (ProhibitNoStrict)
			push @{ $caller.'::ISA' }, $parent;
		}
	};

	return __PACKAGE__->_sm_init_schema($caller, %args);
};

=head3 sm_state 'name' => HANDLER($self, $event), %options;

Define a new state.

'name' MUST be a unique true string.

HANDLER MUST be a subroutine which accepts two parameters:
state machine instance and incoming event.

HANDLER MUST return next state name followed by an arbitrary return value,
both of which MAY be omitted.

HANDLER MAY be omitted, in this case it is replaced with
a diagnostic sub that dies whenever called
to indicate that unexpected event got through to this state.
Use C<sub{}> to silently ignore ALL incoming events.

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

=item * accepting => true scalar

Event sequence leading to this state is said to be accepted by the SM.
NOT only final states may be accepting.

C<$sm_instance-\>accepting> will return exactly the scalar given above
when the machine is in this state, or 0 if it is missing / not true.

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

sub sm_state ($@) { ## no critic (ProhibitSubroutinePrototypes)
	my $name = shift;
	my $handler = _is_sub($_[0]) ? shift : undef;
	croak "sm_state: FATAL: Odd number of arguments"
		if @_%2;

	my $caller = caller;

	my $sm_schema = __PACKAGE__->_sm_init_schema($caller);
	return $sm_schema->add_state( $name => $handler, @_ );
};

=head3 sm_transition 'event_type' => 'new_state', %options;

Add explicit transition from last defined sm_state to another state.

Such transitions are ONLY taken into account if incoming event
belongs to L<FSM::Arrow::Event> or its descendant.
The type() method is called on such event to determine event type.
If type matches transition, main event handler is B<ignored>
and type-local handler is used to determine return value
if needed.

'event_type' must be a string or array of strings.
Unlike for states, empty and 0 are allowed.

'new_state' must be either a (possibly future) state name, or false.
False value means that transition is looped, and callbacks are ignored.

Options may include:

=over

=item * handler => CODEREF($instance, $old_state, $new_state, $event)

Will be executed if present to determine what handle_event() should return.
If it dies, no transition happens.
Signature is the same as that of on_enter, on_leave etc.

=item * on_follow => CODEREF($instance, $old_state, $new_state, $event)

Will be executed if state changes from $old_state to $new_state,
EVEN IF it changes via generic functional handler.

The following pseudocode is perfectly valid:

    sm_state foo => sub { return 'bar' };
	sm_transition [] => 'bar', on_follow => sub { warn "foobared"; };

=back

B<NOTE>: Calling sm_transition automatically updates next state list,
if present.
C<sm_state ..., next => []> is ok.

=cut

sub sm_transition($$@) { ## no critic (ProhibitSubroutinePrototypes)
	my ($types, $new_state, @options) = @_;
	my $caller = caller;

	my $sm_schema = __PACKAGE__->_sm_init_schema($caller);
	my $old_state = $sm_schema->last_added_state;
	croak "sm_transition: FATAL: no states added yet"
		unless $old_state;
	return $sm_schema->add_transition(
		$old_state => $new_state, event => $types, @options );
};

=head3 sm_validate

Check state machine for consistency.
Can be called as a method, static method, or prototyped sub w/o argiments.
In latter case, calling package is assumed as argument.

Dies if violations found, returns nothing otherwise.

The following checks exist for now:

=over

=item * No transitions no nonexistent states exist;

=item * If strict => 1 was specified, all final states are marked as such.

=back

=cut

sub sm_validate (;$) { ## no critic (ProhibitSubroutinePrototypes)
	my $caller = shift || caller;
	my $sm = ref $caller ? $caller->sm_schema : $caller->sm_schema_default;

	croak __PACKAGE__."->validate called by ".(ref $caller || $caller)
		.", but no SM sm_schema could be found"
			unless $sm;

	my $bad = $sm->validate;
	return unless $bad;
	croak __PACKAGE__."->validate(".(ref $caller || $caller)
		."): violations found: ".join "; ", @$bad;
};

sub _sm_init_schema {
	my ($class, $caller, @args) = @_;

	# memoize
	return $sm_schema{ $caller } ||= do {
		my $sm = $class->new( instance_class => $caller, @args );
		my $sm_schema_default = sub { return $sm };

		# Now magic - alter target package
		no strict 'refs';         ## no critic (ProhibitNoStrict)

		push @{ $caller.'::'.'ISA' }, 'FSM::Arrow::Instance';
		*{ $caller.'::'.'sm_schema_default' } = $sm_schema_default;

		$sm;
	};
};

=head1 CONTRACT

A state machine instance class, or B<$instance> hereafter,
MUST exhibit the following properties for the machine to work correctly.

=over

=item * C<$instance> must be a descendant of L<FSM::Arrow::Instance> class.
This is enforced by the first use of sm_init or sm_state.

=item * C<$instance-\>sm_schema()> getter method must be present.
Its return value must be the same C<FSM::Arrow> object
throughout the instance lifetime.

=item * C<$instance-\>state( [new_value] )> accessor method must be present.

=item * Constructor must set both state and sm_schema, even if called without
parameters.

=item * $instance->handle_event($event) method must be left intact, or call
SUPER or C<$instance-\>scheme-\>handle_event($instance, $event)>
at some point if redefined.

=item * Additionally, if OO interface's method spawn() is in use (see below),
the constructor must be named C<new()>, and must accept at least
C<new(sm_schema =\> $object)> parameters.

=back

The following methods are present in FSM::Arrow::Instance,
and should be redefined with care:

C<is_final>, C<accepting>.

User methods starting with C<sm_> should not be defined in FSM::Arrow::Instance
descendants as such names may be taken by future versions of FSM::Arrow.

=head3 Taking care of your custom instance class.

If FSM::Arrow::Instance constructor is left intact or called via SUPER,
no additional action is required.

If constructor is defined from scratch, C<sm_on_construction> method
should be called at some point.
Alternativaly, schema may be found out via sm_schema_default() method
and state can be set manually afterwards.

See section EXTENDING in L<FSM::Arrow::Instance>.

=head1 OBJECT-ORIENTED INTERFACE

One may use FSM::Arrow directly, if needed
- that is, create state machine schemas, spawn instances, and process events.

Declarative interface is actually syntactic sugar over this one.

The state machine is separated into
B<schema> which carries state definitions and metadata
and B<instance> which stores schema reference and the current state.
This may be referred to as I<Strategy> pattern.

A custom instance class may be defined,
provided that it follows CONTRACT (see above).

=head1 SYNOPSIS

    use FSM::Arrow;

    my $sm_schema = FSM::Arrow->new( instance_class => 'My::Context' );
	$sm_schema->add_state( "name" => sub { ... }, next => [ 'more', 'states' ] );
	# ... more or the same

	# much later
	my $instance = $sm_schema->spawn;
	while (<>) {
		my $reply = $instance->handle_event($_);
		print "$reply\n";
		last if $instance->is_final;
	};

	package My::Context;
	use parent qw(FSM::Arrow::Instance);

=head1 METHODS

=cut

=head3 new( %args )

Constructor.

%args may include:

=over

=item * id - This machine id. If unset, a sane default is provided.

=item * parent - if set, clone machine instead.

=item * instance_class - if set, use that class for instances (see spawn).
The default is FSM::Arrow::Instance.

B<NOTE> This does not prohibit using this machine with any other instance class.

=back

See C<sm_init> above for the rest of possible options.

=cut

my %new_args;
$new_args{$_}++ for qw( id instance_class initial_state strict
	on_event on_state_change on_return on_error );

sub new {
	my ($class, %args) = @_;

	_is_sub($args{$_}) or croak __PACKAGE__."->new: $_ must be a subroutine"
		for qw( on_event on_state_change on_return on_error );

	if (my $parent = delete $args{parent}) {
		return $parent->clone( %args );
	};

	my @extra = grep { !$new_args{ $_ } } keys %args;
	croak __PACKAGE__."->new: unexpected arguments @extra"
		if @extra;

	$args{instance_class} ||= 'FSM::Arrow::Instance';

	my $self = bless {}, $class;
	defined $args{$_} and $self->{$_} = $args{$_}
		for keys %new_args;

	# Must do this AFTER self is defined
	$self->{id} ||= $self->generate_id;
	return $self;
};

=head3 clone( %options )

Create a copy of SM schema object.

Cloned state handlers can then be overridden by add_state,
but only once per state.

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
		strict           => $self->{strict},
		%args,
	);

	$new->{states} = _deep_copy($self->{states});

	return $new;
};

# Clone routine.
# Clone hashes, leave everything else (objects, subs) as is
# Storable::dclone cannot into subs
# TODO Performance sucks, but do we need better?
sub _deep_copy {
	my $hash = shift;
	return ref $hash eq 'HASH' ? { map { _deep_copy($_) } %$hash } : $hash;
};

=head3 add_state( 'name' => HANDLER($instance, $event), %options )

Define a new state.

'name' MUST be a unique true string, HANDLER MUST be a subroutine if defined.

HANDLER MUST return next state name followed by an arbitrary return value,
both of which may be omitted.

If HANDLER is undef, it is replaced with a sub that dies whenever called
to indicate that unexpected event got through to this state.
Use C<sub{}> to silently ignore all incoming events.

See C<sm_state> above for detailed description of name, HANDLER,
and available options.

Self is returned (so this method can be chained).

Trying to add a state more than once would cause exception,
UNLESS this is FIRST redefinition of an existing state
in a clone of another machine.

=cut

my %state_args;
$state_args{$_}++ for qw( initial final accepting next
	on_enter on_leave override );

sub add_state {
	$_[0]->_croak( "add_state: odd number of arguments" )
		unless @_%2;
	my ($self, $name, $code, %args) = @_;

	# check input thoroughly
	my @extra = grep { ! $state_args{$_} } keys %args;
	$self->_croak( "add_state: unexpected arguments @extra" )
		if @extra;
	$self->_croak( "add_state: state name must be true string" )
		if !$name || ref $name;
	$self->_croak( "add_state: handler must be a subroutine" )
		unless _is_sub($code);
	$self->_croak( "add_state: state $name already defined" )
		if $self->{state_lock}{ $name } && !$args{override};
	_is_sub( $args{$_} )
		or $self->_croak( "add_state: $_ callback must be a subroutine" )
		for qw(on_enter on_leave);
	$self->_croak( "add_state: next must be array of true strings" )
		if( $args{next}
			&& ( ref $args{next} ne 'ARRAY'
			|| grep { !$_ || ref $_ } @{ $args{next} }));

	# final state has some restrictions...
	if ($args{final}) {
		my @extra_cb = grep { defined $args{$_} } qw(on_leave next);
		$self->_croak( "add_state: options '@extra_cb' forbidden in a final state" )
				if @extra_cb;
	};
	if ($self->{strict}) {
		$args{next} ||= [] unless $args{final};
	};

	# No code was given => ANY event unexpected and unwanted
	$code ||= sub {
		my $explain = (blessed $_ and $_->isa('FSM::Arrow::Event'))
			? (" of type='".$_->type."'") : ('');
		$self->_croak( "Unexpected event$explain received in state '$name'" );
	};

	# now update self
	# NOTE we MUST override ALL options
	# just in case we're redefining an older state.
	# Except for callbacks which may stay.

	# TODO make state an object?
	my $state = {
		name => $name,
		handler => $code,
	};
	if ( $args{initial} || !defined $self->{initial_state} ) {
		$state->{initial} = 1;
		$self->{initial_state} = $name;
	};

	$state->{final} = $args{final} ? 1 : 0;

	$state->{next} = $args{next}
		? _array_to_hash( $args{next} )
		: undef;
	exists $args{$_} and $state->{$_} = $args{$_}
		for qw(on_enter on_leave accepting);

	# Lock state. Note: this is released when object is cloned
	#    to allow state overrides
	$self->{states}{$name} = $state;
	$self->{state_lock}{$name}++;
	$self->{last_added_state} = $name;

	return $self;
};

=head3 add_transition( old_state => new_state, %options )

Adds transition between states.
old_state must be added via add_state at this point, however,
new_state may not yet exist.

Both old_state and new_state must be true strings
(just like any state name).

See C<sm_transition> above for detailed discussion of %options.

=cut

my %trans_args;
$trans_args{$_}++ for qw( event handler on_follow );

sub add_transition {
	my ($self, $from, $to, %args) = @_;

	my @extra = grep { !$trans_args{$_} } keys %args;
	$self->_croak( "add_transition: unexpected arguments @extra" )
		if @extra;
	$self->_croak( "add_transition: old_state must be a true string" )
		if !$from || ref $from;
	$self->_croak( "add_transition: new_state must be a string" )
		if !defined $to || ref $to;

	my $events = $args{event};
	$events = [] unless defined $events;
	$events = [ $events ] unless ref $events eq 'ARRAY';

	my $state = $self->{states}{$from};
	$self->_croak( "add_transition: non-looped transition from final state" )
		if $state->{final} and $from ne $to;

	$state->{next} and $to and $state->{next}{$to} = 1;

	$state->{event_types}{$_} = $to for @$events;

	if (my $handler = $args{handler}) {
		$state->{event_handler}{$_} = $handler for @$events;
	};

	$state->{on_follow}{$to} = $args{on_follow}
		if $args{on_follow};

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
	return \%hash;
};

=head3 spawn()

Returns a new machine instance.

state() is set to initial_state. sm_schema() is set to self.

=cut

sub spawn {
	my $self = shift;

	my $instance = $self->instance_class->new( sm_schema => $self );
	return $instance;
};

=head3 handle_event( $instance, $event || @events )

Process event(s) based on $instance->state and state definition.
Adjust state accordingly.

Returned value is determined by state handler's second optional return value.
See sm_state above for HANDLER discussion.
If multiple events are processed, the LAST such return value is used.

This is normally invoked via C<$instance-\>handle_event( $event )>
and not directly.

This function is reenterable, i.e. a SM object may send events to other SMs
or even itself, and all this keeps working as expected.

=cut

# This is the very core of this module.
sub handle_event {
	my $self = shift;
	my $instance = shift;

	# Coerce incoming events, if needed
	if (my $code = $self->{on_event}) {
		@_ = map { $code->($_); } @_;
	};

	my $queue = $instance->sm_queue;
	if ( $queue ) {
		push @$queue, @_;
		return;
	};

	$instance->sm_queue( \@_ );
	my $ret;
	# we need to restore queue on failure, so eval the whole thing...
	my $success = eval {
		my $on_return = $self->{on_return};
		while (@_) {
			local $_ = shift;

			my $old_state = $instance->state;
			my $new_state;
			my $rules = $self->{states}{$old_state};

			my $ev_type = blessed $_ && $_->isa("FSM::Arrow::Event") && $_->type;

			# Determine next state:
			if ( defined $ev_type
				and defined ($new_state = $rules->{event_types}{ $ev_type })
			) {
				# if typed event is used, try hard transition (type-based)
				my $handler = $rules->{event_handler}{ $ev_type };
				$handler and $ret = $handler->( $instance, $old_state, $new_state, $_ );
			} else {
				# otherwise, try soft transition (method-like)
				my $handler = $rules->{handler};
				($new_state, $ret) = $handler->( $instance, $_ );
			};

			# If state changed
			if ($new_state && !$rules->{final}) {
				# check transition legality
				$self->_croak("Illegal transition '$old_state'->'$new_state'(nonexistent)")
					unless exists $self->{states}{ $new_state };
				$self->_croak("Illegal transition '$old_state'->'$new_state'(forbidden)")
					if $rules->{next} && !$rules->{next}{ $new_state };

				# execute callbacks: leave, enter, generic callback
				my $cblist = $rules->{cache_cb}{$new_state} ||= [
					# HACK grep defined creates unwanted hash keys, add @list to avoid
					grep { defined $_ } my @list_context = (
						$rules->{on_leave},
						$rules->{on_follow}{$new_state},
						$self->{states}{$new_state}{on_enter},
						$self->{on_state_change},
					)
				];
				foreach my $callback ( @$cblist ) {
					$callback->( $instance, $old_state, $new_state, $_ );
				};

				# finally, set state
				$instance->state( $new_state );
			};

			# execute return data callback, if any
			$on_return and $on_return->($instance, $ret);
		}; # while
		1;
	}; # eval

	if (!$success) {
		my $err = $@;
		# get queue before unsetting...
		$queue = $instance->sm_queue;
		$instance->sm_queue( undef );
		$self->{on_error} and $self->{on_error}->( $instance, $err, $queue );
		die $err;
	};
	$instance->sm_queue( undef );

	return $ret;
}; # end sub handle_event

sub _croak {
	croak $_[0]->id.": $_[1]";
};

=head2 DEVELOPMENT/INSPECTION PRIMITIVES

=head3 list_states

List all defined states. initial_state is guaranteed to come first.

=head3 get_state( $name )

Get hashref with state properties. State can be recreated as

    $sm->add_state( delete $ref->{name}, delete $ref->{handler}, %$ref );

See C<sm_state> above.

Dies if no such state exists.

=cut

sub list_states {
	my $self = shift;

	my $first = $self->initial_state;
	return $first, grep { $_ ne $first } keys %{ $self->{states} };
};

sub get_state {
	my ($self, $name) = @_;

	$self->_croak("get_state(): No state named '$name'")
		unless exists $self->{states}{ $name };

	my $data = _deep_copy( $self->{states}{$name} );

	# mangle data for sake of round-trip
	$data->{next} and $data->{next} = [ keys %{ $data->{next} } ];
	$data->{$_} ||= 0 for qw(accepting initial);
	$data->{$_} ||= undef for qw(on_enter on_leave);
	delete $data->{cache_cb};
	return $data;
};

=head3 validate()

B<EXPERIMENTAL>

Checks machine for correctness.
Returns 0 if no violations vere found, true otherwise.
Return format may change.

Criteria include:

=over

=item * all possible transitions lead to existing states.

=item * if machine is strict, final states are marked as such.

=back

=cut

sub validate {
	my $self = shift;

	my %seen;
	$seen{$_}++ for $self->list_states;

	my @violations;
	foreach my $state (keys %seen) {
		my $rules = $self->get_state( $state );
		my @away = grep { !$seen{$_} } @{ $rules->{next} };
		push @violations, "extra transitions: $state=>[@away]"
			if @away;

		if ($self->{strict}) {
			push @violations, "final state $state not marked as such"
				if !@{ $rules->{next} } && !$rules->{final};
		};
	};
	return @violations ? \@violations : 0;
};

=head3 pretty_print

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

=head2 GETTERS

=head3 id()

Returns state machine schema unique identifier.

Unless given explicitly to new(), defaults to generate_id() output.

=cut

sub id {
	return $_[0]->{id};
};

=head3 initial_state()

Returns initial state. Defaults to first added state,
but may be overridden in constructor or add_state.

=cut

sub initial_state {
	return $_[0]->{initial_state};
};

=head3 instance_class()

Returns class that will be used for machine instances by default.
This would be instantiated whenever spawn() is called.

B<NOTE> There is NO requirement that SM instance using this schema
must belong to this class.

=cut

sub instance_class {
	return $_[0]->{instance_class};
};

=head3 is_final( $state_name )

Tells whether $state_name is a final state in the machine.

B<NOTE> Invalid states are ignored, i.e. no exception.
This may change in the future.

B<NOTE> This method is normally not called directly -
call C<$instance-\>is_final()> instead.

=cut

sub is_final {
	my ($self, $state) = @_;

	# $self->_croak("Invalid state $state")
	#     unless $self->{states}{$state};
	return $self->{states}{$state}{final};
};

=head3 accepting( $state_name )

Tells whether given state is an accepting state.
Returns a true scalar denoting outcome type, or 0 if none.

B<NOTE> Invalid states are ignored, i.e. no exception.
This may change in the future.

B<NOTE> This method is normally not called directly -
call $instance->accepting() instead.

=cut

sub accepting {
	my ($self, $state) = @_;
	return $self->{states}{$state}{accepting} || 0;
};

=head2 INTERNAL METHODS

=head3 generate_id()

Returns an unique id containing at least schema and instance class refs.

B<NOTE> This is normally NOT called directly.

=cut

my $id;
sub generate_id {
	my $self = shift;

	my $type = ref $self;
	my $instance = $self->instance_class;

	return "$type<$instance>#".++$id;
};

=head3 last_added_state()

Returns last state added via sm_state or add_state.

B<NOTE> This is normally NOT called directly.

=cut

sub last_added_state {
	return $_[0]->{last_added_state};
};

=head1 ENVIRONMENT VARIABLES

=over

=item * B<FSM_ARROW_NOXS> - by default, L<Class::XSAccessor> is used
if available for performance reasons.
This variable suppresses that behavior.
Can be used for benchmarking, or in case of compatibility issues.

See in C<examples/bench.pl>:

    BEGIN {
        $ENV{FSM_ARROW_NOXS} = 1;
    };

=back

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
