#!/usr/bin/env perl
#
# Use  perl -d:Confess twixt.pl for debugging.

use strict;
use warnings;
#use Data::Dumper;
#use Data::Printer;
use File::Spec;
# Search for our modules in the same directory as our driver.
# Does this get fooled if we get invoked via a symlink?
BEGIN {
    use File::Basename;
    my $filedir = dirname(__FILE__);
    push @INC, $filedir;
}
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
    $parser->{generate_level} = 1;

    if (!@args) {
	push @args, "testfile.xt";
    }

    my %tree;

    for my $filename (@args) {
	#my $tree = $parser->from_file($filename);

	open my $file, "<", $filename;
	$parser->{reader_filename} = $filename;
	$parser->{reader_filestack} = [];
	$parser->{reader_file} = $file;
	$parser->{reader_include_dir} = [ "." ];

	my $twigs = $parser->from_reader(\&reader);

	for my $k (keys %{$twigs}) {
	    $tree{$k} = $twigs->{$k};
	}

	#print STDERR "Returned from parser->from_file: ", Dumper($treepart), "\n";
    }

    analyze_all(\%tree);

    #print STDERR "Returned from analyze_all: ", Dumper(\%tree), "\n";
    #print STDERR "Returned from analyze_all: ";
    #p($tree);
    #print STDERR "\n";

    generate_all(\%tree);

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
	    if ($line =~ /^%\s*include_dir\s*"(.*)"/) {
		my $dirname = $1;
		push @{$parser->{reader_include_dir}}, $dirname;
	    } elsif ($line =~ /^%\s*include\s*"(.*)"/) {
		my $filename = $1;
		# Find the file in the include directories
		DIRS: for my $dir (@{$parser->{reader_include_dir}}) {
		    #my $try = $dir."/".$filename;
		    my $try = File::Spec->catfile($dir, $filename);

		    if (-e $try) {
			$filename = $try;
			last DIRS;
		    }
		}
		push @{$parser->{reader_filestack}}, $file;

		#print STDERR  "%%% including file $filename\n";
		$file = undef;
		open $file, "<", $filename;
		$parser->{reader_file} = $file;

		return defined $lines ? $lines : "";
	    } elsif ($line =~ /^%%/) {
		$lines .= $line;
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

