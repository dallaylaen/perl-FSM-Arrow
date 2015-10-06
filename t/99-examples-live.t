#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

my $output;

ok ($output = run_script( "bench.pl all=1" ));
like ($output, qr(\d+), "Lots of digits in bench output");

ok ($output = run_script( "bit-string.pl", 1, 11, 111, 101 ));
like ($output, qr<11\n1001\n10101\n1111\n>s, "x3 works");

ok ($output = run_script( "transition.pl", "west", "west" ));
like ($output, qr<from.*to>, "transition example works");

done_testing;

# TODO More defensive programming. Open2? Open3?

sub run_script {
	my ($name, @input) = @_;

	$name = "$Bin/../example/$name"; # TODO FindBin?
	my $echo = join "; ", map { "echo '$_'" } @input;
	$echo ||= "true";

	my $ret;
	eval {
		local $SIG{ALRM} = sub {
			die "Alarm during execution of $name";
		};
		my $cmd = "( $echo ) | perl $name";
		note "Executing: $cmd";
		alarm 10;
		$ret = `$cmd`;
		alarm 0;
	};

	if ($@) {
		diag "$@";
		return "";
	};

	if ($?) {
		diag "Error code=$?";
		return "";
	};

	return $ret;
};
