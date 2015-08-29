package FSM::Arrow;

use 5.006;
use strict;
use warnings;

=head1 NAME

FSM::Arrow - Declarative inheritable generic state machine.

=head1 VERSION

Version 0.01

=cut

our $VERSION = 0.0101;

=head1 DESCRIPTION

This module provides a state machine intended for web services
and asynchronous apps.

State machine is represented by a
B<schema> which defines handler for each state
and B<instance> which holds the current state and possibly more data.

=head1 SYNOPSIS

    use FSM::Arrow;

    my $schema = FSM::Arrow->new( instance_class => 'My::Context' );
	$schema->add_state( "name" => sub { ... }, next => [ 'more', 'states' ] );
	# ... more or the same

	# much later
	my $instance = $schema->spawn;
	while (<>) {
		my $reply = $instance->handle_event($_);
		print "$reply\n";
		last if $instance->is_final;
	};

	package My::Context;
	use parent qw(FSM::Arrow::Context);

=head1 EXPORT

Declarative part - when it's done.

=head1 SUBROUTINES/METHODS

=cut

use Carp;

use FSM::Arrow::Context;

=head2 new( %args )

Args may include:

=over

=item * instance_class - the class the machine instances belong to.
Default is FSM::Arrow::Context;

=item * initial_state - inintial machine state.
Default is the first state defined by add_state();

=back

=cut

sub new {
	my ($class, %args) = @_;

	$args{instance_class} ||= 'FSM::Arrow::Context';

	my $self = bless {
		instance_class => $args{instance_class},
		initial_state => $args{initial_state},
		id => $args{id},
	}, $class;

	$self->{id} ||= $self->generate_id;
	return $self;
};

=head2 id()

Returns state machine schema unique identifier.

Unless given explicitly to new(), defaults to generate_id() output.

=cut

sub id {
	return $_[0]->{id};
};

=head2 add_state( 'name' => CODE($instance, $event), %options )

Define a new state.

'name' MUST be a unique true string.

CODE MUST be a subroutine which accepts two parameters - instance and event.

CODE MUST return next state name followed by an arbitrary return value, both
of which may be omitted.

Next state MUST be either a false value, which means no change,
or a valid state name added via add_state as well.

No options are defined yet, but they may be added in the future.

Self is returned (can be chained).

=cut

sub add_state {
	my ($self, $name, $code, %args) = @_;

	$self->{states}->{$name} = $code;
	$self->{initial_state} = $name unless defined $self->{initial_state};
	return $self;
};

=head2 spawn()

Returns a new machine instance.

state() is set to initial_state. schema() is set to self.

=cut

sub spawn {
	my $self = shift;

	my $instance = $self->{instance_class}->new( schema => $self );
	$instance->set_state($self->{initial_state});
	return $instance;
};

=head2 handle_event( $instance, $event )

Process event based on $instance->state and state definition.
Adjust state accordingly.

Return is determined by state handler.

This is normally called as $instance->handle_event( $event ) and not directly.

=cut

sub handle_event {
	my ($self, $instance, $event) = @_;

	my $old_state = $instance->state;
	my $code = $self->{states}{ $old_state };

	my ($new_state, $ret) = $code->( $instance, $event );

	# TODO on_leave
	if ($new_state) {
		$self->_croak("Illegal transition '$old_state'->'$new_state'(nonexistent)")
			unless exists $self->{states}{ $new_state };
		# TODO check legal transitions if available

		$instance->set_state( $new_state );
		# TODO on_enter
	};

	return $ret;
};

sub _croak {
	croak $_[0]->id.": $_[1]";
};

=head2 generate_id()

Returns an unique id containing at least schema and instance class refs.

B<NOTE> This is normally NOT called directly.

=cut

my $id;
sub generate_id {
	my $self = shift;

	my $schema = ref $self;
	my $instance = $self->{instance_class};

	return "$schema<$instance>#".++$id;
};

=head1 AUTHOR

Konstantin S. Uvarin, C<< <khedin at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-fsm-arrow at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=FSM-Arrow>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc FSM::Arrow


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=FSM-Arrow>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/FSM-Arrow>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/FSM-Arrow>

=item * Search CPAN

L<http://search.cpan.org/dist/FSM-Arrow/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2015 Konstantin S. Uvarin.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of FSM::Arrow
