package CPAN::Mirror::FromGit;

# ABSTRACT: Use git repos instead of cpan distributions

use Moose;
use Path::Class ();
use File::Temp;
use Cwd;
use PPI;
use File::HomeDir;
use YAML ();

with 'MooseX::ConfigFromFile';

sub _get_default_config_file {
  my ($class) = @_;
  my $home    = $class->_build_home_dir;
  my $file    = qq{$home/config.yaml};
  open( my ($fh), '>', $file ) || die qq{Couldn't open $file: $!}
    unless -f $file;
  return $file;
}

sub get_config_from_file {
  my ( $class, $file ) = @_;
  return YAML::LoadFile($file);
}

has repos => ( isa => 'ArrayRef', is => 'ro', default => sub { [] } );

has home_dir => ( isa => 'Str', is => 'ro', required => 1, lazy_build => 1 );

has module_index_file =>
  ( isa => 'Str', is => 'ro', required => 1, lazy_build => 1 );

has module_index =>
  ( isa => 'HashRef', is => 'ro', required => 1, lazy_build => 1 );

sub _build_home_dir {
  my $home = File::HomeDir->my_home;
  my $dir  = "$home/.cpangit";
  mkdir($dir) unless -e $dir;
  return $dir;
}

sub _build_module_index_file {
  my $index = shift->home_dir . '/index.yaml';
  open( my ($fh), '>', $index ) || die "Couldn't open $index: $!"
    unless -e $index;
  return $index;
}

sub _build_module_index {
  my ($self) = @_;
  return YAML::LoadFile( $self->module_index_file );
}

sub checkout {
  my ( $self, $repo ) = @_;
  my $curdir = Cwd::getcwd();
  my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );
  chdir($tmpdir);
  my $ts  = time();
  my $cmd = qq{git clone $repo $ts};
  system($cmd);
  chdir($curdir);
  return $tmpdir;
}

sub scan_repo {
  my ( $self, $repo ) = @_;
  my $dir = $self->checkout($repo);
  $dir = Path::Class::dir($dir);
  my @packages;
  $dir->recurse(
    callback => sub {
      my ($file) = @_;
      return unless $file && -f $file;
      return if $file =~ /\.git/;
      my $doc = PPI::Document->new( $file . '' ) or return;
      my $local_pkgs =
        $doc->find(
        sub { $_[1]->isa('PPI::Statement::Package') and $_[1]->namespace } );
      push @packages, map { $_->namespace } @$local_pkgs if $local_pkgs;
    }
  );

  # TODO identify versions
  return map { $_ => undef } grep {length} @packages;
}

sub get_repo_list {
  my ($self) = @_;
  my @repos = @{ $self->repos };
  chomp for @repos;
  return grep { defined && length } @repos;
}

sub build_repo_index {
  my ($self) = @_;
  my @repos = $self->get_repo_list;
  my %index;
  for my $repo (@repos) {
    $self->chat("Building module index for $repo\n");
    my %pkgs = $self->scan_repo($repo);
    $self->chat("Found modules:\n");
    $self->chat("$_\n"), $index{$_} = $repo for keys %pkgs;
  }
  return %index;
}

sub write_repo_index {
  my ($self) = @_;
  my %index = $self->build_repo_index;
  YAML::DumpFile( $self->module_index_file, \%index );
}

sub chat {
    my $self = shift;
    print STDERR @_ if $self->debug;
#    $self->log(@_);
}

sub debug { $ENV{DEBUG} }

1;
