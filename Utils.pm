package Utils;

use strict;
use warnings;

use Data::Dumper;

use Exporter 'import'; # gives you Exporter's import() method directly
our @EXPORT = ();
our @EXPORT_OK = qw(hashed_list_of_hashes);

sub hashed_list_of_hashes
{
    my ($key, $list_of_hashes) = @_;

    my %indexed;

    foreach my $item (@$list_of_hashes) {
	$indexed{$item->{$key}} = $item;
    }

    return \%indexed;
}

1;
