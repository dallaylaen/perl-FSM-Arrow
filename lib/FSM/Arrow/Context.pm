use strict;
use warnings;

package FSM::Arrow::Context;

=head1 NAME

FSM::Arrow::Context - FMS::Arrow state machine instance.

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

our $VERSION = 0.0102;

=head2 new( %args )

Instantiate the object.

$args{schema} must exist and be a FSM::Arrow object.

Normally, this module isn't instantiated; FSM::Arrow->spawn() is called instead.

=cut

sub new {
	my ($class, %args) = @_;

	my $self = bless {
		schema => $args{schema},
	}, $class;

	return $self;
};

=head2 handle_event( $event )

Process incoming event via handler correspondent to the current state.

Returns value is determined by handler.

B<NOTE> The state MAY be changed after this call.

=cut

sub handle_event {
	my ($self, $event) = @_;

	return $self->schema->handle_event( $self, $event );
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
};

=head2 schema()

Returns state machine schema.

=cut

sub schema {
	my $self = shift;
	return $self->{schema};
};


1;
