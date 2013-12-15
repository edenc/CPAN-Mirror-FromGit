use warnings;
use strict;
use FindBin;
use Test::More;

use CPAN::Mirror::FromGit;

my $cmgit = CPAN::Mirror::FromGit->new;

my %modules = $cmgit->scan_repo("file:///${FindBin::Bin}/../.git");

is_deeply( \%modules, { 'CPAN::Mirror::FromGit' => undef } );

done_testing();
