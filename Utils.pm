package Utils;

use strict;
use warnings;

use Data::Dumper;

use Exporter 'import'; # gives you Exporter's import() method directly
our @EXPORT = ();
our @EXPORT_OK = qw(
    hashed_list_of_hashes
    trim
);

sub hashed_list_of_hashes
{
    my ($key, $list_of_hashes) = @_;

    my %indexed;

    foreach my $item (@$list_of_hashes) {
	$indexed{$item->{$key}} = $item;
    }

    return \%indexed;
}

# Trim leading and trailing whitespace.

sub trim
{
    my ($str) = @_;

    $str =~ s/^\s+//;
    $str =~ s/\s+$//;

    return $str;
}

1;
