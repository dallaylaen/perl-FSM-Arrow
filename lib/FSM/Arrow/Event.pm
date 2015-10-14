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

B<NOTE>For performance reasons, L<Class::XSAccessor> is used if available.
This can be suppressed by setting FSM_ARROW_NOXS=1 environment variable.

=cut

our $VERSION = 0.07;

use Carp;
our @CARP_NOT = qw(FSM::Arrow FSM::Arrow::Instance);

# Use XS Accessors if available, for speed & glory
# Normal accessors are still present and work the same (but slower).
my $can_xs = !$ENV{FSM_ARROW_NOXS} && eval { require Class::XSAccessor; 1 };
if ($can_xs) {
	Class::XSAccessor->import(
		replace => 1,
		constructor => 'new',
		getters => { type => 'type', raw => 'raw', },
	);
};

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
