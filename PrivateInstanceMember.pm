package PrivateInstanceMember;

use strict;
use warnings;
use Data::Dumper;
use fields qw(
    comment
    declaration
    declaration_pattern
    declaration_specifiers
    declarator
    field
);
#   With a field description such as
#   void (*funcptr)(int, int), then
#
# declaration			= void (*funcptr)(int, int)
# declaration_pattern		= void (*%s)(int, int)
# declaration_specifiers	= void
# declarator			= (*funcptr)(int, int)
# field				= funcptr

sub new
{
    (my $class, my @fields) = @_;

    bless { @fields }, $class;
}

sub analyze
{
    (my PrivateInstanceMember $self, my Widget $widget) = @_;
    #print "PrivateInstanceMember self = ", Dumper($self), "\n";
    #print "PrivateInstanceMember widget = ", Dumper($widget), "\n";

    my $declaration = $self->{declaration};
    my $comment = $self->{comment} || "";

    # A field in the instance record

    my $field = "    ${declaration}; $comment\n";

    push @{$widget->{code_instance_record}}, [ $field, $self ];
}

1;
