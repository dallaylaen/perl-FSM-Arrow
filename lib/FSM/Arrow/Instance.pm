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

=item * set_state( $scalar ) is present;

=item * state() is present and ALWAYS returns
whatever was given to set_state last time;

=item * handle_event( $scalar ) is not redefined, or wraps around
SUPER::handle_event;

=back

=head1 METHODS

=cut

our $VERSION = 0.0305;

# If event handler ever dies, don't end up blaming Arrow.
# Blame caller of handle_event instead.
use Carp;

our @CARP_NOT = qw(FSM::Arrow);

=head2 new( %args )

Instantiate the object.

$args{schema} must exist and be a FSM::Arrow object.

Normally, this module isn't instantiated; FSM::Arrow->spawn() is called instead.

=cut

sub new {
	my $class = shift;
	croak "Odd number of elements in $class->new(...)"
		if @_ % 2;

	return bless { @_ }, $class;
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

Returns current state name.

=cut

sub state {
	my $self = shift;
	return $self->{state} ||= $self->schema->initial_state;
};

=head2 set_state( $name )

Sets new state. This is normally NOT called directly.

=cut

sub set_state {
	my ($self, $new) = @_;
	$self->{state} = $new;
	return $self;
};

=head2 schema()

Returns state machine schema.

=cut

sub schema {
	my $self = shift;
	no warnings 'once'; ## no critic
	# HACK Avoid warning on syntax check
	# normally we're loaded by FSM::Arrow, so sm_schema DOES exist
	return $self->{schema} ||= $FSM::Arrow::sm_schema{ ref $self };
};

1;
