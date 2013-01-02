
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "simple, intuitive interface to the fork() system call",
  "AUTHOR" => "Aristotle Pagaltzis <pagaltzis\@gmx.de>",
  "BUILD_REQUIRES" => {
    "Test::More" => 0,
    "vars" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Proc-Fork",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Proc::Fork",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Exporter::Tidy" => 0,
    "Object::Tiny::Lvalue" => 0,
    "Scalar::Util" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.800",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



