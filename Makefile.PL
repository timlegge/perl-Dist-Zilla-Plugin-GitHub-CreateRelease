use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Create a GitHub Release",
  "AUTHOR" => "Timothy Legge",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Dist-Zilla-Plugin-GitHub-CreateRelease",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "Dist::Zilla::Plugin::GitHub::CreateRelease",
  "PREREQ_PM" => {
    "Config::Identity" => "0.0019",
    "Digest::SHA" => "6.02",
    "Dist::Zilla" => "2.100921",
    "File::Slurper" => 0,
    "Git::Wrapper" => "0.048",
    "Moose" => "2.2014",
    "Pithub::Repos::Releases" => "0.01040",
    "URI" => 0,
    "URI::Escape" => 0
  },
  "VERSION" => "0.0005",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Config::Identity" => "0.0019",
  "Digest::SHA" => "6.02",
  "Dist::Zilla" => "2.100921",
  "File::Slurper" => 0,
  "Git::Wrapper" => "0.048",
  "Moose" => "2.2014",
  "Pithub::Repos::Releases" => "0.01040",
  "URI" => 0,
  "URI::Escape" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
