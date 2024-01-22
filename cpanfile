# Do not edit this file directly. To change prereqs, edit the `dist.ini` file.

requires "CPAN::Changes" => "0.500002";
requires "Config::INI::Reader" => "0";
requires "Config::Identity" => "0";
requires "Crypt::OpenPGP" => "0";
requires "DDP" => "0";
requires "Digest::SHA" => "0";
requires "Dist::Zilla::Role::AfterRelease" => "0";
requires "Exporter" => "0";
requires "Feature::Compat::Class" => "0";
requires "File::Basename" => "0";
requires "File::Slurper" => "0";
requires "File::Temp" => "0";
requires "Git::Wrapper" => "0";
requires "JSON::MaybeXS" => "1.004000";
requires "LWP::Simple" => "0";
requires "MetaCPAN::Client" => "0";
requires "Module::Signature" => "0";
requires "Moose" => "0";
requires "Pithub::Repos::Releases" => "0";
requires "Try::Tiny" => "0";
requires "URI" => "0";
requires "URI::Escape" => "0";
requires "feature" => "0";
requires "namespace::autoclean" => "0";
requires "perl" => "v5.20.0";
requires "strict" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "Test::More" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::EOF" => "0";
  requires "Test::EOL" => "0";
  requires "Test::More" => "0.88";
  requires "Test::NoTabs" => "0";
  requires "Test::Perl::Critic" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
  requires "Test::Spelling" => "0.12";
  requires "Test::TrailingSpace" => "0.0203";
};
