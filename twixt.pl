#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use TwiXt;
use Widget;
use Generator;

# Only needs to contain the non-identity mappings.
# No XtR will be prepended.
my %common_class_to_reprname = (
    Depth  => "Int",
    Background => "XtRColor",
    Accelerators => "XtRAcceleratorTable",
    Translations => "XtRTranslatorTable",
);

# Only needs to contain the non-identity mappings.
my %common_reprname_to_ctype = (
    "Int" => "int",
    "Long" => "long",
    "Screen" => "Screen *",
);

sub main
{
    my $parser = TwiXt->new(
		    patterns => {
			comment => qr/#.*$/m,
		    },
		);

    my $tree = $parser->from_file("testfile.xt");

    #print "Returned from parser->from_file: ", Dumper($tree), "\n";

    analyze_all($tree);

    print "Returned from analyze_all: ", Dumper($tree), "\n";

    generate_all($tree);

    return 0;
}

sub analyze_all
{
    my $widgets = $_[0];

    foreach my $key (keys %$widgets) {
	$widgets->{$key}->analyze($widgets);
    }
}


main(@ARGV);

