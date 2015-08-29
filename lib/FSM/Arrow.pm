package FSM::Arrow;

use 5.006;
use strict;
use warnings;

=head1 NAME

FSM::Arrow - Declarative inheritable generic state machine.

=cut

our $VERSION = 0.0203;

=head1 DESCRIPTION

This module provides a state machine intended for web services
and asynchronous apps.

State machine is represented by a
B<schema> which defines handler for each state
and B<instance> which holds the current state and possibly more data.

=head1 DECLARATIVE MOOSE-LIKE INTERFACE

	package My::State::Machine;

	use FSM::Arrow qw(:class);

	sm_state initial => sub {
		my ($self, $event) = @_;

		return final => 'Here we go'
			if $event =~ bar;
	};

	sm_state final => sub {};

	# later in calliing code
	use My::State::Machine;

	my $sm = My::State::Machine->new;

	print $sm->state; # initial

	$sm->handle_event( "foo" ); # returns undef, state = initial
	$sm->handle_event( "bar" ); # returns "Here we go", state = final
	$sm->handle_event( "baz" ); # returns undef, state = final

	$sm->isa("FSM::Arrow::Instance"); # true
	$sm->schema; # returns a FSM::Arrow object

B<NOTE> Even though sm_state subs ("handlers") look like methods, one may
define real methods with exactly the same names.

=cut

use Carp;
use parent qw(Exporter);
our @EXPORT_OK = qw(sm_state);
our %EXPORT_TAGS = ( class => [ 'sm_state' ] );

my %sm_schema;

=head2 sm_init %options

Initialize state machine schema with %options. See new() below.
This may be omitted.

sm_init MUST be called no more than once, and before ANY sm_state calls.

=cut

sub sm_init (@) { ## no critic
	croak "sm_init: FATAL: Odd number of arguments"
		if @_%2;

	my $caller = caller;

	croak "sm_init: FATAL: SM schema already initialized"
		if exists $sm_schema{$caller};

	__PACKAGE__->_sm_init_schema($caller, @_);
};

=head2 sm_state 'name' => CODEREF($self, $event), %options;

Create a new state machine state. See add_state() below.

B<NOTE> even though CODEREF looks a lot like a method,
no method with such name is actually created and it is safe to have one.
See CONTRACT below.

=cut

sub sm_state ($$@) { ## no critic
	croak "sm_state: FATAL: Odd number of arguments"
		if @_%2;
	my ($name, $handler, @options) = @_;

	my $caller = caller;

	my $schema = __PACKAGE__->_sm_init_schema($caller);
	$schema->add_state( $name => $handler, @options );
};

sub _sm_init_schema {
	my ($class, $caller, @args) = @_;

	# memoize
	return $sm_schema{ $caller } ||= do {
		my $sm = $class->new( instance_class => $caller, @args );

		my $schema_getter = sub { $sm };

		# Now magic - alter target package
		no strict 'refs';         ## no critic
		no warnings 'redefine';   ## no critic

		push @{ $caller.'::'.'ISA' }, 'FSM::Arrow::Instance';
		*{ $caller.'::'.'schema' } = $schema_getter;

		$sm;
	};
};

=head1 CONTRACT

A state machine instance class, or B<$instance> hereafter,
MUST exhibit the following properties for the machine to work correctly.

C<$instance> must be a descendant of L<FSM::Arrow::Instance> class.
This is enforced by the first use of sm_init or sm_state.

C<$instance->scheme()> method must be present.
Its return value must be the same C<FSM::Arrow> object
throughout the instance lifetime.

C<$instance->set_state($scalar)> method must be present.

C<$instance->state()> method must be present.
Its return value must be the last value given to C<$instance->set_state>,
or C<$instance->scheme->initial_state> if C<set_state> was never called.

$instance->handle_event($event) method must be left intact, or call
C<$instance->scheme->handle_event($instance, $event)>
at some point if redefined.

Additionally, if used with OO interface (see below), the constructor
must be named C<new()>, and must accept C<new(schema => $object)> parameters
resulting in that very object being returned by C<scheme> method.

All of these methods are implemented in exactly that way
in FSM::Arrow::Instance under assumption
that self is a blessed hash and keys C<state> and C<schema> are available.

If Moose is used, no additional care has to be taken (unless these methods
are overridden).

If C<use fields> is used, adding C<state> and C<schema> to the fields list
is required.

=head1 OBJECT-ORIENTED INTERFACE

One may use FSM::Arrow directly, if needed
- that is, create state machine schemas, spawn instances, and process events.

Declarative interface is actually syntactic sugar over this one.

The state machine is separated into
B<schema> which carries state definitions and metadata
and B<instance> which stores schema reference and the current state.

A custom instance class may be defined,
provided that it follows CONTRACT (see above).

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
	use parent qw(FSM::Arrow::Instance);

=head1 METHODS

=cut

use FSM::Arrow::Instance;

=head2 new( %args )

Args may include:

=over

=item * instance_class - the class the machine instances belong to.
Default is FSM::Arrow::Instance;

=item * initial_state - inintial machine state.
Default is the first state defined by add_state();

=back

=cut

sub new {
	my ($class, %args) = @_;

	$args{instance_class} ||= 'FSM::Arrow::Instance';

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

=head2 initial_state()

Returns initial state. Defaults to first added state,
but may be overridden in constructor.

=cut

sub initial_state {
	return $_[0]->{initial_state};
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
