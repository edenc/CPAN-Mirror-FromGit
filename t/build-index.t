use warnings;
use strict;
use FindBin;
use Test::More;
use YAML;

use CPAN::Mirror::FromGit;

# bootstrap test with our own repo
my $repo = "file:///${FindBin::Bin}/../.git";

my $cmgit = CPAN::Mirror::FromGit->new_with_config(
  configfile => "$FindBin::Bin/testconfig.yaml",
  repos      => [$repo],
  home_dir   => $FindBin::Bin
);
my %modules = $cmgit->scan_repo($repo);

is_deeply( \%modules, { 'CPAN::Mirror::FromGit' => undef } );

my %index = $cmgit->build_repo_index;

is_deeply( \%index,
  { 'CPAN::Mirror::FromGit' => "file:///${FindBin::Bin}/../.git" } );

$cmgit->write_repo_index;

is_deeply( YAML::LoadFile( $cmgit->module_index_file ),
  { 'CPAN::Mirror::FromGit' => "file:///${FindBin::Bin}/../.git" } );

unlink $cmgit->module_index_file;

done_testing();
