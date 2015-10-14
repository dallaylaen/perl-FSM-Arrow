#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use FSM::Arrow::Util qw(sm_handler_regex);

my $handler = sm_handler_regex(
	qr(foo) => "foo",
	qr(bar) => [ "bar", "went" ],
	qr(baz(.*)) => [ sub { "baz" }, sub { $_[2] } ],
);

my $sub = sub {
	local $_ = shift;
	my $self = {};
	$handler->($self, $_);
};

is_deeply [ $sub->(undef)     ], [ undef, undef  ], "No undef action";
is_deeply [ $sub->("xxx")     ], [ undef, undef  ], "No default action";
is_deeply [ $sub->("food")    ], [ "foo", undef  ], "Simple state change";
is_deeply [ $sub->("bard")    ], [ "bar", "went" ], "State change with return";
is_deeply [ $sub->("bazooka") ], [ "baz", "ooka" ], "sub substitution";

$handler = sm_handler_regex(
	unknown => [ "xxx", sub { /(...)/ and $1 } ],
	undef   => "stop",
);

is_deeply [ $sub->(42)   ], [ xxx  => ''    ], "defualt, no reg match";
is_deeply [ $sub->(1337) ], [ xxx  => 133   ], "default, reg match";
is_deeply [ $sub->()     ], [ stop => undef ], "data undef";


done_testing;

