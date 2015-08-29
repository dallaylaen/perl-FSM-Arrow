#!perl

use Test::More tests => 1;

BEGIN {
    use_ok( 'FSM::Arrow' ) || print "Bail out!\n";
}

diag( "Testing FSM::Arrow $FSM::Arrow::VERSION, Perl $], $^X" );
