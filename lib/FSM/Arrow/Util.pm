use strict;
use warnings;

package FSM::Arrow::Util;

=head1 NAME

FSM::Arrow::Util - Various subroutine generators for FSM::Arrow.

=head1 DESCRIPTION

L<FSM::Arrow> makes heavi use of callbacks.
However, many of those callbacks repeat the same patterns over and over again.
This package contains subroutine generators for some of such cases.

=cut

our $VERSION = 0.0502;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw( handler_regex_chain event_maker_regex );
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use Carp;
our @CARP_NOT = qw(FSM::Arrow FSM::Arrow::Instance);

use FSM::Arrow::Event;

=head1 SUBROUTINES

All of these subroutines are exported.

B<NOTE> This module is subject to rapid change.

=head2 HANDLERS

=head3 handler_regex_chain( /regex/ => [next_state, do_something], ... )

=cut

sub handler_regex_chain {
	croak "handler_chained_regex: FATAL: odd number of arguments"
		if @_ % 2;

	my $rules = [];
	my ($undef, $default) = ([], []);
	while (@_) {
		my $condition = shift;
		my $action = shift;
		$action = [ $action ] unless ref $action eq 'ARRAY';

		if (ref $condition eq 'Regexp') {
			push @$rules, [ $condition, $action ]; # rex, next, retval
		} elsif ($condition eq 'undef') {
			$undef = $action;
		} elsif ($condition eq 'unknown') {
			$default = $action;
		} else {
			croak "handler_chained_regex: FATAL: Unexpected condition $condition";
		};
	};

	my $handler = sub {
		my $ret;
		my @match;
		if (!defined $_) {
			$ret = $undef;
		} else {
			foreach my $todo ( @$rules ) {
				@match = ($_ =~ $todo->[0]) or next;
				$ret = $todo->[1];
				last;
			};
		};
		$ret ||= $default;

		return (
			ref $ret->[0] eq 'CODE' ?$ret->[0]->($_[0], $_, @match) :$ret->[0],
			ref $ret->[1] eq 'CODE' ?$ret->[1]->($_[0], $_, @match) :$ret->[1],
		);
	};
	return $handler;
};

=head2 EVENT GENERATORS

=head3 event_maker_regex ( %args )

Static method, returns a coderef that constructs
FSM::Arrow::Event from given string.

%args may include:

=over

=item * regex (required) - the regular expression used to parse string.

Any named capture groups, including C<(?\<type\>...)>,
would become event's fields.

First capture group would become type if no type group is defined.

=item * 'undef' - event type that is returned for undefined string.
Default is C<__STOP__>.

=item * unknown - event type that is returned if regex matched,
but type is empty.
Default is C<__ANY__>.

=item * nomatch - event type that is returned if regex didn't match.
If unspecified, the returned sub will die at this point.

=back

=cut

sub event_maker_regex {
	my (%args) = @_;

	defined $args{regex} or croak __PACKAGE__
		."event_maker_regex: FATAL: regex parameter must be present";

	my $re = $args{regex};
	$re = qr($re) unless ref $re eq 'Regexp';

	my $class   = defined $args{class}   ? $args{class}   : "FSM::Arrow::Event";
	my $stop    = defined $args{undef}   ? $args{undef}   : "__STOP__";
	my $unknown = defined $args{unknown} ? $args{unknown} : "__ANY__";
	my $nomatch = $args{nomatch};

	$class->isa("FSM::Arrow::Event")
		or croak "event_maker_regex: FATAL: "
			."class argument must be FSM::Arrow::Event descendant";

	return sub {
		return $class->new(type => $stop, raw => undef)
			unless defined $_[0];

		if ($_[0] =~ $re) {
			no warnings 'uninitialized'; ## no critic
			return $class->new (
				raw => $_[0],
				type => length $1 ? $1 : $unknown,
				%+,
			);
		};

		return $class->new( raw => $_[0], type => $nomatch )
			if defined $nomatch;
		croak "Raw event doesn't match regex $re";
	};
};

=head2 CALLBACKS

Not done yet.

=cut

1;
