use strict;
use warnings;

package Dist::Zilla::Plugin::GitHub::CreateRelease;
# VERSION

# ABSTRACT: Create a GitHub Release

use Pithub::Repos::Releases;
use Config::Identity::GitHub;
use Git::Wrapper;
use File::Basename;
use URI;
use URI::Escape qw( uri_unescape );
use File::Slurper qw/read_text read_binary/;
use Exporter qw(import);
use Moose;
with 'Dist::Zilla::Role::AfterRelease';

use namespace::autoclean;

has hash_alg => (is => 'ro', default => 'sha256');
has repo => (is => 'ro');
has branch => (is => 'ro', default => 'main');
has title_template => (is => 'ro', default => 'Version RELEASE - TRIAL CPAN release');
has notes_as_code => (is => 'ro', default => 1);
has github_notes => (is => 'ro', default => 0);
has notes_from => (is => 'ro', default => 'SignReleaseNotes');
has notes_file => (is => 'ro', default => 'Release-VERSION');
has draft => (is => 'ro', default => 0);
has add_checksum => (is => 'ro', default => 1);

sub _create_release {
  my $self      = shift;
  my $tag       = shift;
  my $branch    = shift;
  my $title     = shift;
  my $notes     = shift;
  my $filename  = shift;
  my $cpan_tar  = shift;

  my %identity = Config::Identity::GitHub->load_check;

  die "Unable to load github token from ~/.github-identity" if (! defined $identity{token});

  my $releases = Pithub::Repos::Releases->new(
    user  => $identity{login} || $self->{username},
    repo  => $self->_get_repo_name() || $self->{repo},
    token => $identity{token},
  );
  die "Unable to instantiate Pithub::Repos::Releases" if (! defined $releases);

  require JSON::MaybeXS;
  my $release = $releases->create(
    data => {
      tag_name         => "$tag",
      target_commitish => $branch,
      name             => $title,
      body             => $notes,
      draft            => $self->{draft} ? JSON::MaybeXS::true : JSON::MaybeXS::false,
      prerelease       => $self->zilla->is_trial ? JSON::MaybeXS::true : JSON::MaybeXS::false,
      generate_release_notes => $self->{github_notes} ? JSON::MaybeXS::true : JSON::MaybeXS::false,
    }
  );
  die "Unable to create GitHub release\n" if (! defined $release->content->{id});

  $self->log("Release created at $releases->{repo} for $identity{login}");

  my $asset = $releases->assets->create(
    release_id   => $release->content->{id},
    name         => $filename,
    data         => $cpan_tar,
    content_type => 'application/gzip',
  );

  if ($asset->code eq '201') {
    $self->log("CPAN archive appended to GitHub release: $tag");
  } else {
    $self->log("Unable to append CPAN archive GitHub release: $tag");
  }

}

sub _get_repo_name {
  my $self;

  my $git = Git::Wrapper->new('./');
  my @url = $git->RUN('config', '--get', 'remote.origin.url');

  #FIXME there must be a better way...
  my $basename = uri_unescape( basename(URI->new( $url[0])->path));
  $basename =~ s/.git//;

  return $basename;

}

sub _generate_release_notes {
  my $self      = shift;
  my $filename  = shift;
  my $notes;

  return "" if (! $self->{add_checksum});

  $notes = $self->_get_checksum($filename);

  return $self->_as_code($notes);
}

sub _get_notes_from_changes {
  my $self      = shift;
  my $filename  = shift;

  my $git = Git::Wrapper->new('./');
  my @tags = $git->RUN('for-each-ref', 'refs/tags/*', '--sort=-taggerdate', '--count=2', '--format=%(refname:short)');

  my $vers = $tags[0];
  my $prev = $tags[1];

  my $file = read_text($self->{notes_file});
  my @lines = split /\n/, $file;
  my $print = 0;
  my $notes = "";
  foreach my $line (@lines) {
    $print = 1 if ($line =~ /^$vers/);
    $print = 0 if ($line =~ /^$prev/);
    $notes .= $line . "\n" if $print;
  }
  return $self->_as_code($notes) if (! $self->{add_checksum});

  $notes .= $self->_get_checksum($filename);

  return $self->_as_code($notes);
}

sub _get_notes_from_file {
  my $self      = shift;
  my $filename  = shift;

  my $version   = $self->_get_version();

  my $notes_file = $self->{notes_file};
  $notes_file    =~ s/VERSION/$version/;

  my $notes     = read_text($notes_file);

  return $self->_as_code($notes) if (! $self->{add_checksum});

  return $self->_as_code($notes) if ($self->{notes_from} eq 'SignReleaseNotes');

  $notes .= $self->_get_checksum($filename);

  return $self->_as_code($notes);

}

sub after_release {
  my $self      = shift;
  my $filename  = shift;

  my $tag       = _get_git_tag();
  my $branch    = $self->{branch};
  my $title     = $self->{title_template};

  $title =~ s/RELEASE/$tag/;
  $title =~ s/TRIAL/Official/ if (!$self->zilla->is_trial);

  my $notes;

  if ($self->{notes_from} eq 'SignReleaseNotes' or $self->{notes_from} eq 'FromFile') {
    $notes = $self->_get_notes_from_file($filename);
  } elsif ($self->{notes_from} eq 'ChangeLog') {
    $notes = $self->_get_notes_from_changes($filename);
  } elsif ($self->{notes_from} eq 'GitHub::CreateRelease') {
    $notes = $self->_generate_release_notes($filename);
  }

  my $cpan_tar  = read_binary($filename);

  my($basename, $dirs, $suffix) = fileparse($filename);

  $self->_create_release($tag, $branch, $title, $notes, $basename, $cpan_tar);
}

sub _as_code {
  my $self = shift;
  my $text = shift;

  return '```' . "\n" . $text . "\n" . '```' if $self->{notes_as_code};
  return $text;
}

sub _get_git_tag {
  my $self     = shift;

  my $git = Git::Wrapper->new('./');

  my @tags = $git->RUN('for-each-ref', 'refs/tags/*', '--sort=-taggerdate', '--count=1', '--format=%(refname:short)');

  return $tags[0];
}

sub _get_checksum {
  my $self     = shift;
  my $filename = shift;

  use Digest::SHA;
  my $sha = Digest::SHA->new($self->{hash_alg});
  my $digest;
  if ( -e $filename ) {
      open my $fh, '<:raw', $filename  or die "$filename: $!";
      $sha->addfile($fh);
      $digest = $sha->hexdigest;
  }

  my $checksum = uc($self->{hash_alg}) . " hash of CPAN release\n";
  $checksum .= "\n";
  $checksum .= "$digest *$filename\n";
  $checksum .= "\n";

  return $checksum;
}

sub _get_version {
  my ($self) = @_;

  return $self->{zilla}->version;
}

sub _get_name {
  my ($self, $filename) = @_;

  $filename =~ s/-+\d+.*$//g;
  $filename =~ s/-/::/g;
  return $filename;
}

sub BUILDARGS {
  my $self = shift;
  my $args = @_ == 1 ? shift : {@_};

  if (not exists $args->{notes_file}) {
    $args->{notes_file} = 'Changes' if ($args->{notes_from} eq 'ChangeLog');
    $args->{notes_file} = 'Release-VERSION' if ($args->{notes_from} eq 'SignReleaseNotes');
  }
  $args;
}

no Moose;

__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=head1 SYNOPSIS

In your F<dist.ini>:

 [GitHub::CreateRelease]
 repo = github_repo_name         ; optional
 branch = main                   ; default = main
 notes_as_code = 1               ; default = 1 (true)
 notes_from = SignReleaseNotes   ; default = SignReleaseNotes
 notes_file = Release-VERSION    ; default = Release-VERSION
 github_notes = 0                ; default = 0 (false)
 draft = 0                       ; default = 0 (false)
 hash_alg = sha256               ; default = sha256
 add_checksum = 1                ; default = 1 (true)
 title_template = Version RELEASE - TRIAL CPAN release      ; this is the default

=head1 Required Plugins

This plugin requires that your Dist::Zilla configuration do the following:

 1. Create a release
 2. Tag the release in your git repository
 3. Push the commits (and tags) to GitHub

There are numerous combinations of Dist::Zilla plugins that can perform those
functions.

=head1 GITHUB API AUTHENTICATION

This module uses Config::Identity::GitHub to access the GitHub API credentials.

You need to create a file in your home directory named B<.github-identity>.  It
requires the following fields:

 login github_username
 token github_....

The GitHub API has a lot of options for the generation of Personal Access Tokens.

At minimum you will need a personal access token with "Write" access to "Contents".
It allows write access to Repository contents, commits, branches, downloads,
releases, and merges.

Config::Identity::GitHub supports a gpg encrypted B<.github-identity> file.  It is
recommended that you implement encryption for the B<.github-identity> file.  If you
have gpg configured you can encrypt the file:

 # Encrypt it to ~/.github-identity.asc
 gpg -ea -r you@example.com ~/.github-identity
 # Cat ~/.github-identity.asc to verify it is encrypted
 cat ~/.github-identity.asc
 # Verify you can decrypt the file
 gpg -d ~/.github-identity.asc
 # Replace the clear text version (uncomment next line)
 # mv ~/.github-identity.asc ~/.github-identity
 
=head1 DESCRIPTION

This plugin will create a GitHub Release and attach a copy of the
cpan release archive to the Release.

The release notes can be generated based on the notes_from value.

This plugin should appear after any other AfterBuild plugin in your C<dist.ini> file.
If you are using SignReleaseNotes as the notes_from it should be after the
SignReleaseNotes plugin.

=head1 ATTRIBUTES

=over

=item hash_alg

A string value for the B<Digest::SHA> supported hash algorithm to use for the hash of the
cpan upload file.

=item repo

A string value that specifies the name of the github repository.  The module determines the
name based on the remote url but this setting can override the name that is detected.

=item branch

A string value that specifies the branch.  It defaults to B<main> if not specified.

=item title_template

A string value that specifies the format of the Title used for the release.  If the
title includes B<VERSION> it is replaced with the version number of the release.  If the
title includes B<TRIAL> it is replaced with Official or Trial depending on whether --trial
was specified.

The default value is "Version VERSION - TRIAL CPAN release"

=item notes_as_code

An integer value specifying true/false.  If the value is true (not 0) the notes are surrounded by
the github code markup "```" ... "```".

=item github_notes

An integer value specifying true/false.  If the value is true (not 0) the api call instructs
github to add a link to the changes in the release.

=item notes_from

A string value that specifies how to obtain the Notes for the Release.  The valid values
are:

=over

=item SignReleaseNotes

=item ChangeLog

=item FromFile

=item GitHub::CreateRelease

=back

=item notes_file

A string value specifying the name template of the notes file that should be read
for to obtain the notes.  It is used for if the B<note_from> is one of:

 SignReleaseNotes
 FromFile
 ChangeLog

The default is B<Release-VERSION> and VERSION is replaced by the module version
number if it exists.

=item draft

An integer value specifying true/false.  If the value is true (not 0) the api call instructs
github that the Release is a draft.  You must publish it via the github webpage to make
it active.

=back

=head1 METHODS

=over

=item after_release

The main processing function that is called automatically after the release is complete.

=back

=head1 AUTHOR

  Timothy Legge <timlegge@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2023 by Timothy Legge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

