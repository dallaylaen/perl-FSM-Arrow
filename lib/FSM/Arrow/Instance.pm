package FSM::Arrow::Instance;

use strict;
use warnings;

=head1 NAME

FSM::Arrow::Instance - FMS::Arrow state machine instance.

=head1 DESCRIPTION

This module is used to store state of a state machine,
while FMS::Arrow itself only contains metadata.

One can (and is encouraged to) extend this class,
provided that the following contract is held:

=over

=item * new() accepts a C<sm_schema => $scalar> parameter;

=item * sm_schema() ALWAYS returns that $scalar after that;

=item * state() is present and ALWAYS returns
whatever was given to it last time;

=item * handle_event( $scalar ) is not redefined, or wraps around
SUPER::handle_event;

=back

B<NOTE>For performance reasons, L<Class::XSAccessor> is used if available.
This can be suppressed by setting FSM_ARROW_NOXS=1 environment variable.

=head1 METHODS

=cut

## no critic (RequireArgUnpacking)
our $VERSION = 0.0702;

# If event handler ever dies, don't end up blaming Arrow.
# Blame caller of handle_event instead.
use Carp;
our @CARP_NOT = qw(FSM::Arrow);

use fields qw(state sm_schema sm_queue);
use Scalar::Util qw(refaddr);

# Use XS Accessors if available, for speed & glory
# Normal accessors are still present and work the same (but slower).
my $can_xs = !$ENV{FSM_ARROW_NOXS} && eval { require Class::XSAccessor; 1 };
if ($can_xs) {
	Class::XSAccessor->import(
		replace => 1,
		getters => { sm_schema => 'sm_schema' },
		accessors => { state => 'state', sm_queue => 'sm_queue' },
	);
};

=head2 new( %args )

%args may include:

=over

=item * sm_schema - a FSM::Arrow object that holds the state metadata;

=item * state - the initial state name;

=item * any other key/value pairs.

=back

B<NOTE> See EXTENDING section below if you intend to override new().

=cut

sub new {
	my $class = shift;
	croak "Odd number of elements in $class->new(...)"
		if @_ % 2;

	my %args = @_;
	$args{sm_schema} ||= $class->sm_schema_default;
	$args{state}  ||= $args{sm_schema} && $args{sm_schema}->initial_state;
	return bless \%args, $class;
};

=head2 handle_event( $event, ... )

Process incoming event via handler correspondent to the current state.

If one event is processed, returns whatever was the second return value
of the state/transition handler.
If several events are processed, returns the I<last> such value.
If another event is being processed already, appends events to the queue
and returns nothing.

One might want to use on_return callback instead of return value
in case processing multiple events and/or recursion is anticipated.

B<NOTE> The state MAY be changed after this call.

=cut

sub handle_event {
	# Delegate the hard work to FSM::Arrow
	# so that all concerted code modifications are local to that file.
	return $_[0]->sm_schema->handle_event(@_);
};

=head2 sm_prepend_event( $event, ... )

Handle given event(s) immediately, before any other pending events.

Return value pattern follows that of C<handle_event>.

=cut

sub sm_prepend_event {
	my $self = shift;
	if (my $queue = $self->sm_queue) {
		unshift @$queue, @_;
		return;
	} else {
		return $self->handle_event(@_);
	};
};

=head2 state()

Without arguments, returns current state.

=head2 state( $new_state_name )

With one argument, sets new state. Returns self (this is not required
by CONTRACT though).

B<NOTE> This should normally NOT be called directly,
as state change callbacks and limitations will be ignored.

=cut

# NOTE We're already setting default state in constructor, however,
# using Moose would override constructor.
sub state { ## no critic (ProhibitBuiltinHomonyms)
	my $self = shift;

	return $self->{state} unless @_;
	$self->{state} = shift;
	return $self;
};

=head2 sm_queue( [] )

Get/set event queue array.
Per-instance event queues are needed for reenterable event handling.

B<NOTE> This should NEVER be called directly.

=cut

sub sm_queue {
	my $self = shift;

	return $self->{sm_queue} unless @_;
	$self->{sm_queue} = shift;
	return $self;
};

=head2 is_final()

Tells whether current state is final.

=cut

sub is_final {
	my $self = shift;
	return $self->sm_schema->is_final( $self->state );
};

=head2 accepting()

Return the outcome type/name for the current state, or 0 if none.

See C<accepting> parameter in sm_state.

=cut

sub accepting {
	my $self = shift;
	return $self->sm_schema->accepting( $self->state );
};

=head2 sm_schema()

Returns state machine shared metadata.

=cut

sub sm_schema {
	return $_[0]->{sm_schema};
};

=head2 EXTENDING

If you are going to replace new() or otherwise change object construction,
call C<sm_on_construction> somewhere in your constructor so that state machine
keeps working as expected.

If you use Moose:

    package My::SM;
    use Moose;
    use FSM::Arrow qw(:class);
    # ... lots of definitions
    sub BUILD { $_[0]->sm_on_construction };

If you use fields:

    package My::SM;
    use fields qw(...); # Whatever fields you need
    use FSM::Arrow qw(:class);
    # ... lots of definitions
    sub new {
        my $class = shift;
		my $self = fields::new( $class );
		# set up fields
		$self->sm_on_construction;
    }

B<NOTE> This sub sets C<$self-\>{sm_schema}> directly.
This may change in the future.
However, getting sm_schema and getting/setting state are done via accessors,
and this is going to stay.

=head3 sm_on_construction

Receives no arguments.
Sets sm_schema and state, if possible.
Returns self.

=cut

sub sm_on_construction {
	my $self = shift;

	my $sm_schema; # some caching for the sake of premature optimisation
	if (!($sm_schema = $self->sm_schema)) {
		$sm_schema = $self->sm_schema_default;
		$self->{sm_schema} = $sm_schema; # sm_schema is a r/o accessor, so do like this
	};
	if ($sm_schema && !$self->state) {
		$self->state( $sm_schema->initial_state );
	};

	return $self;
};

=head3 sm_schema_default

Returns FSM::Arrow machine for a SM class defined via declarative interface.

Dies unless declarative interface was indeed used.

=cut

sub sm_schema_default {
	croak "FSM::Arrow::Instance: 'sm_schema' argument missing in constructor"
		." and declarative API not in use";
};

=head3 sm_to_string

Returns human-readable, unique machine identifier for debugging purposes.

This default implementation is guaranteed to contain at least machine class,
current state, and some unique string.

Current format is "ref/sm_number/refaddr/state",
but this may change in the future.

Optional args may be given, they will be appended to string,
so that one can call C<$self-\>SUPER::sm_to_string( "foo=1", "bar=2" );>
in redefining this method if needed.

=cut

# TODO or should we cache it?
sub sm_to_string {
	my $self = shift;
	return join '/', ref $self, $self->sm_schema->short_id,
		refaddr $self, $self->state, @_;
};

1;
