package CPAN::Mirror::FromGit;
use Moose;
use Path::Class ();
use File::Temp;
use Cwd;
use PPI;

# ABSTRACT: Use git repos instead of cpan distributions

sub checkout {
  my($self, $repo) = @_;
  my $curdir = Cwd::getcwd();
  my $tmpdir = File::Temp::tempdir();
  chdir($tmpdir);
  my $ts = time();
  system(qq{git clone $repo $ts});
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
  return map { $_ => undef } @packages;
}

1;
