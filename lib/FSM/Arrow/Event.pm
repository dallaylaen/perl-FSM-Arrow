use strict;
use warnings;

package FSM::Arrow::Event;

=head1 NAME

FSM::Arrow::Event - event base class for FSM::Arrow state machine.

=cut

our $VERSION = 0.05;

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
