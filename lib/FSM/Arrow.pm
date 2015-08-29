package FSM::Arrow;

use 5.006;
use strict;
use warnings;

=head1 NAME

FSM::Arrow - Declarative inheritable generic state machine.

=head1 VERSION

Version 0.01

=cut

our $VERSION = 0.01;

=head1 DESCRIPTION

This module provides a state machine implementation.
Each state is a subroutine that receives context and event,
and returns the name of the next state.
Context is a special class included in this package (see below).
Event can be anything.

=head1 SYNOPSIS

    use FSM::Arrow;

    my $schema = FSM::Arrow->new( context => 'My::Context' );
	$schema->add_state( "name" => sub { ... }, next => [ 'more', 'states' ] );
	# ... more or the same

	# much later
	my $machine = $schema->spawn;
	while (<>) {
		my $reply = $machine->handle_event($_);
		print "$reply\n";
		last if $machine->is_final;
	};

	package My::Context;
	use parent qw(FSM::Arrow::Context);

=head1

=head1 EXPORT

Declarative part - when it's done.

=head1 SUBROUTINES/METHODS

=cut

use FSM::Arrow::Context;

=head2 new( %args )

Args may include:

=over

=item * context - the class the machine instances belong to.
Default is FSM::Arrow::Context;

=item * initial_state - inintial machine state.
Default is the first state defined by add_state();

=back

=cut

sub new {
	my ($class, %args) = @_;

	$args{context} ||= 'FSM::Arrow::Context';

	my $self = bless {
		context_class => $args{context},
		initial_state => $args{initial_state},
	}, $class;
	return $self;
};

=head2 add_state( 'name' => CODE, %options )

Define a new state.

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

	my $instance = $self->{context_class}->new( schema => $self );
	$instance->set_state($self->{initial_state});
	return $instance;
};

=head2 handle_event( $context, $event )

Process event based on $context->state and state definition.
Adjust state accordingly.

Return is determined by state handler.

This is normally called as $context->handle_event( $event ) and not directly.

=cut

sub handle_event {
	my ($self, $context, $event) = @_;


	my $old_state = $context->state;
	my $code = $self->{states}{ $old_state };

	my ($new_state, $ret) = $code->( $context, $event );
	$context->set_state( $new_state ) if $new_state;

	return $ret;
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
