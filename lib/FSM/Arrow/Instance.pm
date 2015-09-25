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

our $VERSION = 0.0404;

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
	$args{schema} ||= $FSM::Arrow::sm_schema{ $class };
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

	if (@_) {
		$self->{state} = shift;
		return $self;
	};

	if (!exists $self->{state}) {
		$self->{state} = $self->get_initial_state;
	};
	return $self->{state};
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

=head2 get_initial_state()

=cut

sub get_initial_state {
	my $sm = $_[0]->schema;
	return $sm && $sm->initial_state;
};

=head2 schema()

Returns state machine schema.

=cut

sub schema {
	my $self = shift;

	$self->{schema} = $FSM::Arrow::sm_schema{ ref $self }
		unless exists $self->{schema};
	return $self->{schema};
};

1;
