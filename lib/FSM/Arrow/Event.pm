use strict;
use warnings;

package FSM::Arrow::Event;

=head1 NAME

FSM::Arrow::Event - event base class for FSM::Arrow state machine.

=head1 DESCRIPTION

L<FSM::Arrow> can handle any type of data, including raw strings,
unblessed hashes, custom objects, etc.
However, it also supports explicit transitions which specify
event type and next state.
See C<sm_transition> and C<add_transition> in L<FSM::Arrow>
for more information.

This class is what FSM::Arrow expects as incoming event
to make use of such transitions.
It is designed to carry at least type, raw event data,
and any arbitrary data which is at user's discretion.

See also L<FSM::Arrow::Util> for event generator functions.

=cut

use Carp;
our @CARP_NOT = qw(FSM::Arrow FSM::Arrow::Instance);

our $VERSION = 0.0502;

=head1 METHODS

=head3 new( %options )

Constructor. Any options may be passed and will be saved in the object
as $self->{foo}.

Special options are:

=over

=item * type - event's type.
This value will be used to trigger SM transactions.

=item * raw - the data event was created from, if needed.

=back

=cut

sub new {
	my ($self, %opt) = @_;

	# TODO Should we die if type isn't given?
	return bless \%opt, $self;
};

=head3 type()

Returns event's type.

=cut

sub type {
	return $_[0]->{type};
};

=head3 raw()

Returns event's raw data (if specified).

=cut

sub raw {
	return $_[0]->{raw};
};

1;
