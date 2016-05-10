package CodeBlock;

use strict;
use warnings;
use Widget;
use Data::Dumper;
use fields qw(
    body
    name
);

sub new
{
    (my $class, my @fields) = @_;

    bless { @fields }, $class;
}

sub analyze
{
    (my CodeBlock $self, my Widget $widget) = @_;
}

sub append
{
    (my CodeBlock $self, my $extra) = @_;

    $self->{body} .= $extra;
}
1;
