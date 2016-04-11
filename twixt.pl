#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;

package TwiXt;
use parent 'Parser::MGC';

use Data::Dumper;

sub parse
{
    my $self = shift;

    $self->skip_ws();

    my $widgets = $self->list_of( ";",
	sub { $self->widget() }
    );

    my %hash;

    for my $w (@$widgets) {
	$hash{$w->{Name}} = $w;
    }

    return \%hash;

}

####
#
# Parse a widget:
#
# widget FooWidget : Core {
# 	...
# };
#
sub widget
{
    my $self = shift;

    $self->expect("widget");

    my $name = $self->ident_camelcase();

    my $super;
    my $hassuper = $self->maybe_expect(":");
    if ($hassuper) {
	$super = $self->ident_camelcase();
    }

    $self->commit();
    my $members = $self->scope_of_block( sub {
	$self->all_of(
	    sub { $self->class_member_definitions(); },
	    sub { $self->instance_member_definitions(); }
	)
    } );

    print Dumper({
	Name    => $name,
	super   => $super,
	members => $members
    }), "\n";
    return {
	Name             => $name,
	super            => $super,
	class_members    => $members->[0],
	instance_members => $members->[1],
    };
}

sub class_member_definitions
{
    my $self = shift;

    $self->expect("class");
    $self->commit();

    $self->scope_of_block( sub {
	$self->sequence_of ( sub {
	    $self->any_of(
		sub { $self->expect("dummy-class-member") },
		sub { $self->expect("override") },
	    )
	} )
    } );
}
# Members can be resources (and then they are settable via
# XtSetValues() etc, or just private.
# The order is relevant, because we want to be able to describe
# the existing widgets in a compatible way.

sub instance_member_definitions
{
    my $self = shift;

    $self->expect("instance");
    $self->commit();

    $self->scope_of_block( sub {
	$self->sequence_of ( sub {
	    $self->any_of(
		sub { $self->resource_definition(); },
		sub { $self->private_field_definition(); }
	    )
	} )
    } );
}

sub resource_definition
{
    my $self = shift;

    my $class = undef;
    my $init = undef;

    $self->expect("public");
    $self->expect(":");
    $self->commit();

    my $repr = $self->ident_camelcase();
    if ($self->maybe_expect("(")) {
	$class = $self->ident_camelcase();
	$self->expect(")");
    }
    my $field = $self->ident_lowercase();
    if ($self->maybe_expect("=")) {
	$init = $self->substring_before(";");
	length $init or $self->fail( "Expected a C initializer expression ';'" );
    }

    $self->expect(";");

    return {
	is_public => 1,
	field     => $field,
	repr      => $repr,
	class     => $class,
	init      => $init,
    };
}

sub private_field_definition
{
    my $self = shift;

    $self->expect("private:");
    $self->expect(";");
    $self->commit();
}

# Meta-rule
sub scope_of_block
{
    my $self = shift;

    my $code = shift;

    $self->scope_of( "{", $code, "}" );
}

# Meta-rule
# Expect all of the code refs in sequence and return a reference to a
# list containing their results.
# XXX Doesn't do fancy commit handling.
sub all_of
{
    my $self = shift;
    
    my @result = ();

    for my $code (@_) {
	push @result, $self->$code();
    }

    return \@result;
}

# CamelCase
sub ident_camelcase
{
    my $self = shift;

    my $token = $self->token_ident();

    if ($token =~ /_/ || $token !~ /^[[:upper:]]/) {
	$self->fail("Identifier should be CamelCase");
    }

    return $token;
}

# lower_case
sub ident_lowercase
{
    my $self = shift;

    my $token = $self->token_ident();

    if ($token =~ /[[:upper:]]/) {
	$self->fail("Identifier should be lower_case");
    }

    return $token;
}

package main;

sub main
{
    my $parser = TwiXt->new(
		    patterns => { 
			comment => qr/#.*$/
		    }
		);

    my $tree = $parser->from_file("testfile.xt");

    print Dumper($tree), "\n";

    generate_all($tree);
}

sub generate_all
{
    my $hash = shift;

    my $key;
    my $value;

    while (($key, $value) = each %$hash) {
	generate_one($value, $hash);
    }
}

#
# Turn CamelCaseName into camel_case_name.
#

sub lowerclassname
{
    my $name = shift;

    $name =~ s/[A-Z]/_\l$&/g;
    $name =~ s/^_//;

    return $name;
}

sub generate_one
{
    my $hash = shift;
    my $allclasses = shift;

    my $Name = $hash->{Name};

    (my $NAME = $Name) =~ tr/a-z/A-Z/;
    (my $name = $Name) =~ s/^./\l$&/;
    my $lname = lowerclassname($Name);
    my $Public_h_file_name = $Name.".h";
    my $Private_h_file_name = $Name."P.h";

    $hash->{Public_h_file_name} = $Public_h_file_name;
    $hash->{Private_h_file_name} = $Private_h_file_name;
    $hash->{name} = $name;
    $hash->{lname} = $lname;
    $hash->{NAME} = $NAME;

    generate_public_h_file($hash, $allclasses);
    generate_private_h_file($hash, $allclasses);
}

sub generate_public_h_file
{
    my $hash = shift;
    my $allclasses = shift;

    my $Public_h_file_name = $hash->{Public_h_file_name};
    my $NAME = $hash->{NAME};
    my $name = $hash->{name};
    my $lname = $hash->{lname};
    my $Name = $hash->{Name};

    open FILE, ">", $Public_h_file_name;
    print FILE <<HERE_EOF;
#ifndef ${NAME}_H
#define ${NAME}_H

/* New resources */

/* Class record pointer */
extern WidgetClass *${name}Class;

/* C Widget type definition */
typedef struct _${Name}Rec      *${Name};
/* New class method entry points */

#endif /* ${NAME}_H */
HERE_EOF
    close FILE;
}

sub generate_private_h_file
{
    my $hash = shift;
    my $allclasses = shift;

    my $Private_h_file_name = $hash->{Private_h_file_name};
    my $NAME = $hash->{NAME};
    my $name = $hash->{name};
    my $lname = $hash->{lname};
    my $Name = $hash->{Name};

    # Calculate all superclass record declarations
    my $superclassdecls = "";
    my $superinstdecls = "";

    my $super = $hash->{super};

    while (defined $super && exists $allclasses->{$super}) {
	my $sclass = $allclasses->{$super};

	my $Classname = $sclass->{Name};
	my $lclassname = lowerclassname($Classname);

	my $line = "    ${Classname}ClassPart ${lclassname}_class;\n";
	$superclassdecls = $line . $superclassdecls;

	$line = "    ${Classname}Part ${lclassname};\n";
	$superinstdecls = $line . $superinstdecls;

	$super = $sclass->{super};
    }

    open FILE, ">", $Private_h_file_name;
    print FILE <<HERE_EOF;
#ifndef ${NAME}P_H
#define ${NAME}P_H

/* Include public header */
#include <${Name}.h>

/* New representation types used by the ${Name} widget */

/* New fields for the ${Name} instance record */
typedef struct {
/* Settable resources */
     // ...
/* Data derived from resources */
     // ...
} ${Name}Part;

/* Full instance record declaration */
typedef struct _${Name}Rec {
${superinstdecls}
    ${Name}Part ${lname};
} ${Name}Rec;

/* Types for ${Name} class methods */

/* New fields for the ${Name} class record */
typedef struct {
    //...
} ${Name}ClassPart;

/* Full class record declaration */
typedef struct _${Name}ClassRec {
${superclassdecls}
    ${Name}ClassPart ${lname}_class;
} ${Name}ClassRec;

/* Class record variable */
extern ${Name}ClassRec ${name}ClassRec;

/* defines */
#define ${Name}InheritSetText ((${Name}SetTextProc)_XtInherit)
#define ${Name}InheritGetText ((${Name}GetTextProc)_XtInherit)


#endif /* ${NAME}P_H */
HERE_EOF
    close FILE;
}

main();

