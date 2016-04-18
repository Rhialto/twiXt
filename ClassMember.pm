package ClassMember;

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
    (my ClassMember $self, my Widget $widget) = @_;

    #print "ClassMember::analyze, before: ", Dumper($self, $widget), "\n";
    # Test if this is an own field or an override for a superclass field
    if (exists $self->{field}) {
	$self->{code_class_decl} =
	"        ".$self->{declaration}.";\n";

#	$self->{code_init_self} =
#	"        .".$self->{field}." = ".$self->{init_self}.",\n";
#
#	$self->{code_init_subclass} =
#	"        .".$self->{field}." = ".$self->{init_subclass}.",\n";

	$self->{code_init_pattern} =
	"        .".$self->{field}." = %s,\n";
    }

    #print "ClassMember::analyze, after ", Dumper($self, $widget), "\n";
}

1;
