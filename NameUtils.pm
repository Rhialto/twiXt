package NameUtils;

use strict;
use warnings;

use Exporter 'import'; # gives you Exporter's import() method directly
our @EXPORT = qw(	anycase2UPPERCASE
			CamelCase2camelCase
			CamelCase2lower_case
			lower_case2camelCase
			lower_case2CamelCase
			is_CamelCase
			is_lower_case
			);
our @EXPORT_OK = @EXPORT;
	
use Data::Dumper;


sub anycase2UPPERCASE
{
    my $name = $_[0];

    $name =~ tr/a-z/A-Z/;

    return $name;
}

#
# Turn CamelCaseName into camelCaseName
#
sub CamelCase2camelCase
{
    my $name = $_[0];

    $name =~ s/^./\l$&/;

    return $name;
}

#
# Turn CamelCaseName into camel_case_name.
#

sub CamelCase2lower_case
{
    my $name = $_[0];

    $name =~ s/[A-Z]/_\l$&/g;
    $name =~ s/^_//;

    return $name;
}

#
# Turn lower_case into CamelCase
#

sub lower_case2camelCase
{
    my $name = $_[0];

    $name =~ s/_([a-z])/\u$1/g;

    return $name;
}

#
# Turn lower_case into camelCase
#

sub lower_case2CamelCase
{
    my $name = $_[0];

    $name =~ s/_([a-z])/\u$1/g;
    $name =~ s/^([a-z])/\u$1/g;

    return $name;
}

#
# Check if an identifier is pure CamelCase
#
sub is_CamelCase
{
    my $name = $_[0];

    return $name =~ /^[[:upper:]][[:alnum:]]*$/;
}

#
# Check if an identifier is pure lower_case
#
sub is_lower_case
{
    my $name = $_[0];

    return $name =~ /^[[:lower:]_][[:lower:][:digit:]_]*$/;
}

1;
