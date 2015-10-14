#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Scalar::Util qw(looks_like_number);
use FindBin qw($Bin);

my $output;

ok ($output = run_script( "bench.pl all=1" ));
like ($output, qr(\d+), "Lots of digits in bench output");

ok ($output = run_script( "bit-string.pl", 1, 11, 111, 101 ));
like ($output, qr<11\n1001\n10101\n1111\n>s, "x3 works");

ok ($output = run_script( "transition.pl", "west", "west" ));
like ($output, qr<from.*to>, "transition example works");

if (avail("AnyEvent::Socket", 5.010, )) {
	ok( $output = run_script( "ae-phone.pl", "join 1234", "dial 1234" ) );
	like $output, qr(OK.*1234), "AE example works";
};

if (avail("Plack::Request")) {
	my $app = eval { do "$Bin/../example/runner.psgi" };
	is (ref $app, 'CODE', "PSGI example returned a subroutine" );
	if (ref $app eq 'CODE') {
		my $return = $app->({});
		note explain $return;
		is (scalar @$return, 3, "3-element array returned");
		is ($return->[0], "200", "200 returned");
		like $return->[2][0], qr(<title>), "HTML within";
	};
};

done_testing;

# TODO More defensive programming. Open2? Open3?

sub avail {
	my @modules = @_;

	my @missing;
	foreach (@modules) {
		my ($module, @args) = ref $_ ? @$_ : $_;
		my $result = eval {
			if (looks_like_number($module)) {
				require $module;
			} else {
				# Hand-crafted `use`
				my $file = $module;
				$file =~ s{::}{/}g;
				$file .= '.pm';
				require $file;
				$module->import( @args );
			};
			1;
		};
		note "Failed $module: $@" if !$result;
		$result or push @missing, $module;
	};
	if (@missing) {
		diag "Skipping test - failed to load @missing";
		return 0;
	};

	return 1;
};

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
