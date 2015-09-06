#!/usr/bin/env perl

# This is a very clumsy stateful web-service example.
# No authorization, no JSON, no nothing.
# However, it DOES demonstrate how FSM::Arrow can be used in web apps:
#
# 1. Extract incoming event
# 2. Determine session (1 and 2 are independent so can be swapped)
# 3. Load state machine by session or create new
# 4. Feed event to state machine, get reply
# 5. Save new state
# 6. Serve response (5 and 6 can be swapped as well)
#
# The state machine, the request handler, and save/load routines
# are independent. Such isolation can and should be maintained in
# any production application that follows this scheme.

use strict;
use warnings;
use Plack::Request;

# We want the version of FSM::Arrow from this very package first
use FindBin qw($Bin);
use lib "$Bin/../lib";

# The FSM part.

# Note that one could require this script and have fun with My::SM
# w/o web part at all
{
	package My::SM;
	use FSM::Arrow qw(:class);

	# Let's have some debug in case things go wrong
	sm_init on_state_change => sub { warn "$_[0]->{session}: $_[1]=>$_[2]" };

	# The machine itself is very simple:
	# [ start ] ----> [ running ] ----> [ stop ]
	#            run     ^    |    stop
	#                    |run |
	#                    +----+
    # Both straight transitions return a value, the looped one doesn't.
	# We also keep the total distance ran in SM object.

	# The event model is plain hash in our case, but an object
	# could probably be better in a more complex app.

	sm_state start => sub {
		my ($self, $ev) = @_;

		if ($ev->{run} and $ev->{run} > 0) {
			$self->{distance} = $ev->{run};
			return running => "Started!";
		};
		# If control reaches here, nothing is returned, which is interpreted
		# as no state change and no output.
	};

	sm_state running => sub {
		my ($self, $ev) = @_;

		if ($ev->{run} and $ev->{run} > 0) {
			$self->{distance} += $ev->{run};
		};

		if ($ev->{stop}) {
			return stop => "Stopped!";
		};
	};

	sm_state stop => sub {
	}, final => 1;

	# Done with state definitions.
	# Now we continue just like a normal class.
	# Note that constructor has already been provided by FSM::Arrow::Instance,
	# though one may want to override it in a real app.
	# (Moose? Class::XSAccessor? )

	# Show status. Or should we be returning a hash and format it via
	# a template engine or serializer? We should in a real app.
	# Ideally, a state machine class should do these 3 things:
	# receive events, report its current status, and load/save itself.
	sub status {
		my $self = shift;

		return "Session: $self->{session}\nState: $self->{state}\nDistance: "
			.($self->{distance} || 0);
	};

	# Storage part - sorry, no database here!
	# In a real world app, however, storing objects in memory "as is"
	# would not suffice.
	# The good thing is that store/load knows NOTHING about the states
	# except the fact that there's a "state" field in class, among others.
	# NOTE These could also be defined in a parent class - although
	# FSM::Arrow adds its own ISA, normal inheritance is preserved.
	my $incr;
	my %storage;
	sub load {
		my ($class, $session) = @_;

		return $class->new( session => ++$incr )
			unless $session;

		return $storage{$session};
	};

	# OK, this is redundant, overwriting self with self...
	# There would be something less ridiculous in a real app.
	sub save {
		my $self = shift;
		$storage{ $self->{session} } = $self;
	};

	sub delete {
		my $self = shift;
		delete $storage{ $self->{session} };
	};
};
# The state machine class ends here.

# Now PSGI part. See `perldoc Plack` for details.
# We only need a minimal thing that can show some text in a browser...
my $help; # see below

my $app = sub {
	my $req = Plack::Request->new(shift);

	# 1. Extract event, extract session
	my $event = get_event ( $req )
		or return [ 200, [ "Content-Type" => "text/html" ], [ $help ] ];
	my $session = get_session( $req );

	# 2. Load/create state machine from session
	my $sm = My::SM->load( $session );
	if (!$sm) {
		return [ 404, [ "Content-Type" => "text/plain" ]
			, [ "Session not found: $session" ]];
	};

	# 3. Feed event to SM. We SHOULD eval this
	# but let's leave that as an exercise for now.
	my $reply = $sm->handle_event( $event );
	my $result = $reply ? "Result: $reply\n" : "";

	# 4. Save state.
	$sm->save;

	# 5. Serve response.
	return [ 200, [ "Content-Type" => "text/plain" ],
		[ $result, $sm->status ]]
};

# Extract event from incoming request. This could be in separate class
# if needed. But PLEASE don't put it into SM class which SHOULD NOT
# depend on the environment where possible.
sub get_event {
	my $req = shift;

	# return query parameters as a hash.
	# No duplicate values allowed.
	# The last one overrides the first.
	return unless $req->path eq '/event';
	return {
		map { $_ => [ $req->param($_) ]->[-1] } $req->param,
	};
};

# Extract session from incoming data. Some kind of authorization,
# cookie handling, etc. could be here.
# But here in a beautiful world of useless examples
# saying "I'm Carl" is enough for being Carl.
sub get_session {
	my $req = shift;
	return [ $req->param("session") ]->[-1];
};

my $title = "Help - FSM::Arrow PSGI web service example";

$help = <<"HTML";
<html>
	<head>
		<title>$title</title>
	</head>
	<body>
		<h1>$title</h1>
		<p>This is an example of stateful web service. The state diagram
		is as follows: </p>
		<pre>
[ start ] ----> [ running ] ----> [ stop ]
           run     ^    |    stop
                   |run |
                   +----+
		</pre>
		<p>Both straight transitions return a value, the looped one doesn't.
		We also keep the total distance ran.</p>

		<p>Many separate sessions with independent states may exist.</p>

		<p>Send events as the form below describes.
		Leave session blank to create a new one.
		Leave everything else blank for status inquiry.</p>
		<form method="GET" action="/event">
			/event?session=<input name="session" size="5">&amp;run=<input name="run" size="5">&amp;stop=<input type="checkbox" name="stop">
			<input type="submit" value="Send event">
		</form>
	</body>
</html>
HTML

$app = $app; # redundant assignment to avoid warning when `perl -c $0`
