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

our $VERSION = 0.0701;

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

use overload '""' => 'to_string';
use Scalar::Util qw(refaddr);

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

=head3 to_string

Returns human-readable, unique event identifier for debugging purposes.

This default method is guaranteed to return at least event type,
and to be human-readable.
One may want to redefine it in their application.

The current format is "ref/refaddr/type", but it may change inthe future.
DO NOT rely on pretty-print format.

Optional args may be given, they will be appended to string,
so that one can call C<$self-\>SUPER::to_string( "foo=1", "bar=2" );>
in redefined method if needed.

=cut

sub to_string {
	my $self = shift;
	return join '/', ref $self, refaddr $self, $self->type, @_;
};

1;
