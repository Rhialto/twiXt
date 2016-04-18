package PrivateInstanceMember;

use strict;
use warnings;
use Data::Dumper;

sub new
{
    my $class;
    my @fields;
    ($class, @fields) = @_;

    bless { @fields }, $class;
}

sub analyze
{
    (my PrivateInstanceMember $self, my Widget $arg) = @_;
}

