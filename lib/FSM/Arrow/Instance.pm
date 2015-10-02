use strict;
use warnings;

package FSM::Arrow::Instance;

=head1 NAME

FSM::Arrow::Instance - FMS::Arrow state machine instance.

=head1 DESCRIPTION

This module is used to store state of a state machine,
while FMS::Arrow itself only contains metadata.

One can (and is encouraged to) extend this class,
provided that the following contract is held:

=over

=item * new() accepts a C<schema => $scalar> parameter;

=item * schema() ALWAYS returns that $scalar after that;

=item * state() is present and ALWAYS returns
whatever was given to it last time;

=item * handle_event( $scalar ) is not redefined, or wraps around
SUPER::handle_event;

=back

=head1 METHODS

=cut

our $VERSION = 0.0501;

# If event handler ever dies, don't end up blaming Arrow.
# Blame caller of handle_event instead.
use Carp;

our @CARP_NOT = qw(FSM::Arrow);

=head2 new( %args )

%args may include:

=over

=item * schema - a FSM::Arrow object that holds the state metadata;

=item * state - the initial state name;

=item * any other key/value pairs.

=back

This constructor is as simple as possible and can be overridden by
Moose, Class::XSAccessor, etc. if needed.

=cut

sub new {
	my $class = shift;
	croak "Odd number of elements in $class->new(...)"
		if @_ % 2;

	my %args = @_;
	$args{schema} ||= $class->get_default_sm;
	$args{state}  ||= $args{schema} && $args{schema}->initial_state;
	return bless \%args, $class;
};

=head2 handle_event( $event )

Process incoming event via handler correspondent to the current state.

Returns value is determined by handler.

B<NOTE> The state MAY be changed after this call.

=cut

sub handle_event {
	# Delegate the hard work to FSM::Arrow
	# so that all concerted code modifications are local to that file.
	$_[0]->schema->handle_event(@_);
};

=head2 state()

Without arguments, returns current state.

=head2 state( $new_state_name )

With one argument, sets new state. Returns self (this is not required
by CONTRACT though).

B<NOTE> This is normally NOT called directly.

=cut

# NOTE We're already setting default state in constructor, however,
# using Moose would override constructor.
sub state {
	my $self = shift;

	return $self->{state} unless @_;
	$self->{state} = shift;
	return $self;
};

=head2 is_final()

Tells whether current state is final.

=cut

sub is_final {
	my $self = shift;
	return $self->schema->is_final( $self->state );
};

=head2 accepting()

Return the outcome type/name for the current state, or 0 if none.

See C<accepting> parameter in sm_state.

=cut

sub accepting {
	my $self = shift;
	return $self->schema->accepting( $self->state );
};

=head2 schema()

Returns state machine schema.

=cut

sub schema {
	return $_[0]->{schema};
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
    use fields qw(schema state); # and probably more fields there
    use FSM::Arrow qw(:class);
    # ... lots of definitions
    sub new {
        my $class = shift;
		my $self = fields::new( $class );
		# set up fields
		$self->sm_on_construction;
    }

B<NOTE> This sub sets C<$self-\>{schema}> directly.
This may change in the future.
However, getting schema and getting/setting state are done via accessors,
and this is going to stay.

=head3 sm_on_construction

Receives no arguments.
Sets schema and state, if possible.
Returns self.

=cut

sub sm_on_construction {
	my $self = shift;

	my $schema; # some caching for the sake of premature optimisation
	if (!($schema = $self->schema)) {
		$schema = $self->get_default_sm;
		$self->{schema} = $schema; # schema is a r/o accessor, so do like this
	};
	if ($schema and !$self->state) {
		$self->state( $schema->initial_state );
	};

	return $self;
};

=head3 get_default_sm

Returns FSM::Arrow machine for a SM class defined via declarative interface.

Dies unless declarative interface was indeed used.

=cut

sub get_default_sm {
	croak "FSM::Arrow::Instance: 'schema' argument missing in constructor"
		." and declarative API not in use";
};

1;
