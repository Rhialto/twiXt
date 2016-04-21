package PrivateInstanceMember;

use strict;
use warnings;
use Data::Dumper;
use fields qw(
);

sub new
{
    (my $class, my @fields) = @_;

    bless { @fields }, $class;
}

sub analyze
{
    (my PrivateInstanceMember $self, my Widget $arg) = @_;
}

