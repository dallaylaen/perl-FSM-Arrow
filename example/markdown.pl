#!/usr/bin/env perl

# This is a very clumsy markdown line-by-line state machine.
#

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";

{
	package My::Parser;
	use FSM::Arrow qw(:class);

#	sm_init on_state_change => sub { warn "DEBUG $_[1]=>$_[2]\n" };
	sm_state text => sub {
		!defined and return "fin" => '';
		!/\S/ and return 0 => '';
		/^\s/ and return code => "<pre>$_";
		/^\S/ and return para => "<p>$_";
	};

	sm_state code => sub {
		!defined and return "fin" => "</pre>\n";
		!/\S/ and return wait => '';
		/^\s/ and return 0 => $_;
		/^\S/ and return para => "</pre>\n<p>$_";
	};

	sm_state para => sub {
		!defined and return "fin" => "</p>\n";
		!/\S/ and return text => "</p>\n";
		return 0 => $_;
	};

	sm_state wait => sub {
		!defined and return "fin" => "</pre>\n";
		!/\S/ and return 0 => '';
		/^\s/ and return code => "\n$_";
		/^\S/ and return para => "</pre>\n<p>$_";
	};

	sm_state fin => sub {}, final => 1;
};

my $sm = My::Parser->new;

while (<DATA>) {
	print $sm->handle_event($_);
};
print $sm->handle_event(); # EOF
__DATA__


text text text

     code
     code

     more
     code

text

text

     some code
and text
and text

and more text




