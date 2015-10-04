use strict;
use warnings;

package FSM::Arrow::Event;

=head1 NAME

FSM::Arrow::Event - event base class for FSM::Arrow state machine.

=cut

use Carp;
our @CARP_NOT = qw(FSM::Arrow FSM::Arrow::Instance);

our $VERSION = 0.0501;

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

=head1 GENERATOR METHODS

These static methods create functions
that can make FSM::Arrow::Event objects from incoming raw data.
This may be useful in conjunction with L< FSM::Arrow>'s C<on_check_event>
callback.

=head3 generator_regex ( %args )

Static method, returns a coderef that constructs
FSM::Arrow::Event from given string.

%args may include:

=over

=item * regex (required) - the regular expression used to parse string.

Any named capture groups, including C<(?\<type\>...)>,
would become event's fields.

First capture group would become type if no type group is defined.

=item * stop - event type that is returned for undefined string.
Default is C<__STOP__>.

=item * unknown - event type that is returned for no type.
Default is C<__ANY__>.

=back

=cut

sub generator_regex {
	my ($class, %args) = @_;

	defined $args{regex} or croak __PACKAGE__
		."->generator_regex: regex parameter must be present";

	my $re = $args{regex};
	$re = qr($re) unless ref $re eq 'Regexp';

	my $stop    = defined $args{stop}    ? $args{stop}    : "__STOP__";
	my $unknown = defined $args{unknown} ? $args{unknown} : "__ANY__";

	return sub {
		return $class->new(type => $stop, raw => undef)
			unless defined $_[0];

		$_[0] =~ $re or croak "Raw event doesn't match regex $re";

		no warnings 'uninitialized'; ## no critic
		return $class->new (
			raw => $_[0],
			type => length $1 ? $1 : $unknown,
			%+,
		);
	};
};

1;
