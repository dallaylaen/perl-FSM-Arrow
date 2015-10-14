use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'FSM::Arrow',
    AUTHOR              => q{Konstantin S. Uvarin <khedin@gmail.com>},
    VERSION_FROM        => 'lib/FSM/Arrow.pm',
    ABSTRACT_FROM       => 'lib/FSM/Arrow.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'    => 0.88,
        'Scalar::Util'  => 0,
        'FindBin'       => 0,
        'Carp'          => 0,
        'Exporter'      => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'FSM-Arrow-*' },
);
