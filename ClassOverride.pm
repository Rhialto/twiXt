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

    # Check if the overridden class is actually a superclass of $widget.

    my $class = $self->{name};

    if (!$widget->is_subclass_of($class)) {
	warn "Override of class '$class' in '$widget->{Name}' is invalid: it is not a superclass.";
    }
}

1;
