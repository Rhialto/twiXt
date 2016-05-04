#!/usr/bin/env perl
#
# Use  perl -d:Confess twixt.pl for debugging.

use strict;
use warnings;
#use Data::Dumper;
#use Data::Printer;
use TwiXt;
use Widget;
use Generator;

sub main
{
    my @args = @_;

    my $parser = TwiXt->new(
		    patterns => {
			comment => qr/#.*$/m,
		    },
		);

    if (!@args) {
	push @args, "testfile.xt";
    }

    for my $filename (@args) {
	#my $tree = $parser->from_file($filename);

	open my $file, "<", $filename;
	$parser->{reader_filename} = $filename;
	$parser->{reader_filestack} = [];
	$parser->{reader_file} = $file;

	my $tree = $parser->from_reader(\&reader);

	#print STDERR "Returned from parser->from_file: ", Dumper($tree), "\n";

	analyze_all($tree);

	#print STDERR "Returned from analyze_all: ", Dumper($tree), "\n";
	#print STDERR "Returned from analyze_all: ";
	#p($tree);
	#print STDERR "\n";

	generate_all($tree);
    }

    return 0;
}

sub analyze_all
{
    my $widgets = $_[0];

    foreach my $key (keys %$widgets) {
	$widgets->{$key}->analyze($widgets);
    }
}

# Simple preprocessing reader which will %include files when asked.
sub reader
{
    my $parser = $_[0];

    my $file = $parser->{reader_file};

    my $lines = undef;

    for (;;) {

	my $line = <$file>;

	if (!defined $line) { # end of current file
	    $file = pop @{$parser->{reader_filestack}};
	    #print STDERR  "%%% EOF\n";
	    return $lines if ! defined $file; # end of toplevel file
	    next;
	}

	#print STDERR "line: ", $line;

	if ($line =~ /^%/) {
	    if ($line =~ /^%\s*include\s*"(.*)"/) {
		my $filename = $1;
		push @{$parser->{reader_filestack}}, $file;

		#print STDERR  "%%% including file $filename\n";
		$file = undef;
		open $file, "<", $filename;
		$parser->{reader_file} = $file;

		return defined $lines ? $lines : "";
	    } else {
		print STDERR  "Unrecognized preprocessing line: ", $line;
	    }
	    $line = "";
	}

	$lines .= $line;
    }

    return $lines;

}

main(@ARGV);

