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
    my $superclass = $widget->is_subclass_of($class);

    #print "ClassOverride::analyze: self=", Dumper($self), "\n";
    #print "ClassOverride::analyze: widget=", Dumper($widget), "\n";

    if (!$superclass) {
	warn "Override of class '$class' in '$widget->{Name}' is invalid: it is not a superclass.";
    }

    # Check if all fields do occur in the named superclass.

    for my $field (values %{$self->{fields}}) {
	my $fieldname = $field->{field};
	my $ok = 0;

	# Check if the superclass has this field
	for my $m (@{$superclass->{class_members}}) {
	    $ok++ if ($m->{field} eq $fieldname);
	}

	if (!$ok) {
	    warn "Override of field '$class.$fieldname' in '$widget->{Name}' is invalid: the superclass does not have that class field.";
	}
    }
}

1;
