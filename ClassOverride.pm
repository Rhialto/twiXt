package ClassOverride;

use strict;
use warnings;
use Data::Dumper;
use Widget;

sub new
{
    my $class;
    my @fields;
    ($class, @fields) = @_;

    bless { @fields }, $class;
}

sub analyze
{
    (my ClassOverride $self, my Widget $widget) = @_;
}

1;
