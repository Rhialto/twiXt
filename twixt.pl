#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;

package TwiXt;

use strict;
use warnings;
use parent 'Parser::MGC';
use Data::Dumper;

sub parse
{
    my $self = $_[0];

    $self->skip_ws();

    my $widgets = $self->list_of( ";",
	sub { $self->widget() }
    );

    my %widget;

    for my $w (@$widgets) {
	$widget{$w->{Name}} = $w;
    }

    return \%widget;

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
    my $self = $_[0];

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

#    print Dumper({
#	Name    => $name,
#	super   => $super,
#	members => $members
#    }), "\n";
    return Widget->new(
	Name             => $name,
	super            => $super,
	class_members    => $members->[0],
	instance_members => $members->[1],
    );
}

sub class_member_definitions
{
    my $self = $_[0];

    $self->expect("class");
    $self->commit();

    $self->scope_of_block( sub {
	$self->sequence_of ( sub {
	    $self->any_of(
		sub { $self->override_class_member() },
		sub { $self->class_member_definition() },
	    )
	} )
    } );
}

sub class_member_definition
{
    my $self = $_[0];

    $self->expect("dummy-class-member");

    return ClassMember->new(
	what => "dummy"
    );
}

sub override_class_member
{
    my $self = $_[0];

    $self->expect("override");

    return ClassMember->new(
	what => "override"
    );
}

# Members can be resources (and then they are settable via
# XtSetValues() etc, or just private.
# The order is relevant, because we want to be able to describe
# the existing widgets in a compatible way.

sub instance_member_definitions
{
    my $self = $_[0];

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

#  public: Pixel(Color) background = (Black + White) / 2;
#  public: Int(Int) testint : int = 3;

sub resource_definition
{
    my $self = $_[0];

    my $class = undef;
    my $init = undef;
    my $ctype = undef;

    $self->expect("public");
    $self->expect(":");
    $self->commit();

    my $repr = $self->ident_camelcase();
    if ($self->maybe_expect("(")) {
	$class = $self->ident_camelcase();
	$self->expect(")");
    }
    my $field = $self->ident_lowercase();

    if ($self->maybe_expect(":")) {
	$ctype = $self->substring_before(qr/[=;]/);
    }

    if ($self->maybe_expect("=")) {
	$init = $self->substring_before(";");
	length $init or $self->fail( "Expected a C initializer expression ';'" );
    } else {
	$init = "0";
    }

    $self->expect(";");

    return Resource->new(
	field     => $field,
	repr      => $repr,
	class     => $class,
	ctype     => $ctype,
	init      => $init,
    );
}

sub private_field_definition
{
    my $self = $_[0];

    $self->expect("private:");
    $self->expect(";");
    $self->commit();

    return PrivateInstanceMember->new(
    );
}

# Meta-rule
sub scope_of_block
{
    (my $self, my $code) = @_;

    $self->scope_of( "{", $code, "}" );
}

# Meta-rule
# Expect all of the code refs in sequence and return a reference to a
# list containing their results.
# XXX Doesn't do fancy commit handling.
sub all_of
{
    (my $self, my @codes) = @_;
    
    my @result = ();

    for my $code (@codes) {
	push @result, $self->$code();
    }

    return \@result;
}

# CamelCase
sub ident_camelcase
{
    my $self = $_[0];

    my $token = $self->token_ident();

    if ($token =~ /_/ || $token !~ /^[[:upper:]]/) {
	$self->fail("Identifier should be CamelCase");
    }

    return $token;
}

# lower_case
sub ident_lowercase
{
    my $self = $_[0];

    my $token = $self->token_ident();

    if ($token =~ /[[:upper:]]/) {
	$self->fail("Identifier should be lower_case");
    }

    return $token;
}

package Widget;

use strict;
use warnings;

sub new
{
    my $class;
    my @fields;
    ($class, @fields) = @_;

    bless { @fields }, $class;
}

sub analyze
{
    (my Widget $self, my $allwidgets) = @_;

    return if (exists $self->{analyzed});

    print "Analyzing $self->{Name}\n";

    my $super = $self->{super};
    if (defined $super && exists $allwidgets->{$super}) {
	print "but first Analyzing $super\n";
	$allwidgets->{$super}->analyze($allwidgets);
    }

    $self->{analyzed}++;

    my $Name = $self->{Name};

    my $NAME = main::anycase2UPPERCASE($Name);
    my $name = main::CamelCase2camelCase($Name);
    my $l_name = main::CamelCase2lower_case($Name);

    # Derive different capitalizations
    $self->{name} = $name;
    $self->{l_name} = $l_name;
    $self->{NAME} = $NAME;

    # Derive file names
    $self->{Public_h_file_name} = $Name.".h";
    $self->{Private_h_file_name} = $Name."P.h";
    $self->{c_file_name} = $Name.".c";

    # Derive various structure type names
    $self->{instance_record_type} = $Name."Rec";
    $self->{instance_part_type} = $Name."Part";

    $self->{class_record_type} = $Name."ClassRec";
    $self->{class_record_part_type} = $Name."ClassPart";

    $self->{class_record_instance} = $name."ClassRec";
    $self->{class_record_instance_ptr} = $name."Class";

    # Calculate (super)class record declarations

    $self->{class_part_instance_decl} =
	"    $self->{class_record_part_type} ${l_name}_class;\n";
    $self->{instance_part_instance_decl} =
	"    $self->{instance_part_type} ${l_name};\n";

    $self->{all_class_part_instance_decls} = "";
    $self->{all_instance_part_instance_decls} = "";

    if (defined $super && exists $allwidgets->{$super}) {
	my $sclass = $allwidgets->{$super};
	$self->{all_class_part_instance_decls} = 
	    $sclass->{all_class_part_instance_decls} . $self->{class_part_instance_decl};
	$self->{all_instance_part_instance_decls} = 
	    $sclass->{all_instance_part_instance_decls} . $self->{instance_part_instance_decl};
    } else {
	$self->{all_class_part_instance_decls} = 
	    $self->{class_part_instance_decl};
	$self->{all_instance_part_instance_decls} = 
	    $self->{instance_part_instance_decl};
    }

    $self->{code_xtn} = [];
    $self->{code_xtc} = [];
    $self->{code_xtr} = [];
    $self->{code_resources} = [];

    # Analyze class_members (type ClassMember)
    if (defined (my $mems = $self->{class_members})) {
	foreach my $m (@$mems) {
	    $m->analyze($self);
	}
    }

    # Analyze instance_members (type Resource and PrivateInstanceMember)
    if (defined (my $mems = $self->{instance_members})) {
	foreach my $m (@$mems) {
	    $m->analyze($self);
	}
    }
}

package Resource;

# a.k.a. public or settable instance member.

use strict;
use warnings;
use Data::Dumper;

sub new
{
    my $class;
    my @fields;
    ($class, @fields) = @_;

    bless { @fields }, $class;
}

# A resource generates various things:
# #define for resource name
#                      class
#                      representation
# a field in the FooThingPart
sub analyze
{
    (my Resource $self, my Widget $widget) = @_;

    print "Resource::analyze self = ", Dumper($self), "\n";
    print "Resource::analyze widget = ", Dumper($widget), "\n";

    my $l_name = $self->{field};
    my $Name = main::lower_case2CamelCase($l_name);
    my $name = main::lower_case2camelCase($l_name);
    my $Class = $self->{class};
    my $Repr = $self->{repr};

    if (! defined $Repr) {
	$Repr = $main::common_class_to_reprname{$Class};
	if (! defined $Repr) {
	    $Repr = $Class;
	}
	$self->{repr} = $Repr;
    }
    my $ctype = $main::common_reprname_to_ctype{$Repr};
    if (! defined $ctype) {
	$ctype = $Repr;
    }
    $self->{ctype} = $ctype;

    # A resource generates various things:
    # #define for resource name
    #                      class
    #                      representation
    my $n = "#define XtN${name} \"${name}\"\n";
    my $c = "#define XtC${Class} \"${Class}\"\n";
    my $r = "#define XtR${Repr} \"${Repr}\"\n";

    push @{$widget->{code_xtn}}, [ $n, $self ];
    push @{$widget->{code_xtc}}, [ $c, $self ];
    push @{$widget->{code_xtr}}, [ $r, $self ];

    # A structure for resource init and get/set
    my $res = "    {\n".
              "        XtN${name},\n".
              "        XtC${Class},\n".
              "        XtR${Repr},\n".
              "        sizeof (${ctype}),\n".
              "        XtOffsetOf($widget->{instance_record_type}, $widget->{l_name}.$l_name),\n".
              "        XtRImmediate,\n".	# TODO!
              "        $self->{init},\n".
	      "    },\n";

    push @{$widget->{code_resources}}, [ $res, $self ];
}

package PrivateInstanceMember;

sub new
{
    my $class;
    my @fields;
    ($class, @fields) = @_;

    bless { @fields }, $class;
}

sub analyze
{
    (my $self, my $arg) = @_;
}

package ClassMember;

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
}

package main;

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
			comment => qr/#.*$/
		    }
		);

    my $tree = $parser->from_file("testfile.xt");

    #print Dumper($tree), "\n";

    analyze_all($tree);
    generate_all($tree);
}

sub analyze_all
{
    my $widgets = $_[0];
    
    foreach my $key (keys %$widgets) {
	$widgets->{$key}->analyze($widgets);
    }
}

sub generate_all
{
    my $hash = $_[0];

    my $key;
    my $value;

    while (($key, $value) = each %$hash) {
	generate_one($value, $hash);
    }
}

sub anycase2UPPERCASE
{
    my $name = $_[0];

    $name =~ tr/a-z/A-Z/;

    return $name;
}

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

sub generate_one
{
    (my Widget $widget, my $allwidgets) = @_;

    generate_public_h_file($widget, $allwidgets);
    generate_private_h_file($widget, $allwidgets);
    generate_c_file($widget, $allwidgets);
}

sub generate_public_h_file
{
    (my $widget, my $allwidgets) = @_;

    print "generate_public_h_file: widget = ", Dumper($widget), "\n";

    my $Public_h_file_name = $widget->{Public_h_file_name};
    my $NAME = $widget->{NAME};
    my $name = $widget->{name};
    my $l_name = $widget->{l_name};
    my $Name = $widget->{Name};

    my $xtns = "";
    my $xtcs = "";
    my $xtrs = "";

    if (exists $widget->{code_xtn}) {
	for my $m (@{$widget->{code_xtn}}) {
	    $xtns .= $m->[0];
	}
    }

    if (exists $widget->{code_xtc}) {
	for my $m (@{$widget->{code_xtc}}) {
	    $xtcs .= $m->[0];
	}
    }

    if (exists $widget->{code_xtr}) {
	for my $m (@{$widget->{code_xtr}}) {
	    $xtrs .= $m->[0];
	}
    }

    open FILE, ">", $Public_h_file_name;
    print FILE <<HERE_EOF;
#ifndef ${NAME}_H
#define ${NAME}_H

/* Resource names */
${xtns}
/* Resource classes */
${xtcs}
/* Resource representation types */
${xtrs}

/* New resources */

/* Class record pointer */
extern WidgetClass *${name}Class;

/* C Widget type definition */
typedef struct ${Name}Rec      *${Name};
typedef struct $widget->{instance_record_type} *${Name};

/* New class method entry points */

#endif /* ${NAME}_H */
HERE_EOF
    close FILE;
}

sub generate_private_h_file
{
    (my $widget, my $allwidgets) = @_;

    my $Private_h_file_name = $widget->{Private_h_file_name};
    my $NAME = $widget->{NAME};
    my $name = $widget->{name};
    my $l_name = $widget->{l_name};
    my $Name = $widget->{Name};

    open FILE, ">", $Private_h_file_name;
    print FILE <<HERE_EOF;
#ifndef ${NAME}P_H
#define ${NAME}P_H

/* Include public header */
#include <$widget->{Public_h_file_name}>

/* New representation types used by the ${Name} widget */

/* New fields for the ${Name} instance record */
typedef struct {
/* Settable resources */
     // ...
/* Data derived from resources */
     // ...
} $widget->{instance_part_type};

/* Full instance record declaration */
typedef struct $widget->{instance_record_type} {
$widget->{all_instance_part_instance_decls}
} $widget->{instance_record_type};

/* Types for ${Name} class methods */

/* New fields for the ${Name} class record */
typedef struct {
    //...
} $widget->{class_record_part_type};

/* Full class record declaration */
typedef struct $widget->{class_record_type} {
$widget->{all_class_part_instance_decls}
} $widget->{class_record_type};

/* Class record variable */
extern $widget->{class_record_type} *$widget->{class_record_instance_ptr};

/* defines */
#define ${Name}InheritSetText ((${Name}SetTextProc)_XtInherit)
#define ${Name}InheritGetText ((${Name}GetTextProc)_XtInherit)


#endif /* ${NAME}P_H */
HERE_EOF
    close FILE;
}

sub generate_c_file
{
    (my $widget, my $allwidgets) = @_;

    my $c_file_name = $widget->{c_file_name};
    my $NAME = $widget->{NAME};
    my $name = $widget->{name};
    my $l_name = $widget->{l_name};
    my $Name = $widget->{Name};

    my $all_resources = "";

    if (exists $widget->{code_resources}) {
	for my $m (@{$widget->{code_resources}}) {
	    $all_resources .= $m->[0];
	}
    }

    open FILE, ">", $c_file_name;
    print FILE <<HERE_EOF;
/******************************************************************
 *
 * $Name Resources
 *
 ******************************************************************/

static XtResource respources[] = {
$all_resources
};

static struct $widget->{class_record_type} $widget->{class_record_instance} = {
    // TODO
};

$widget->{class_record_type} *$widget->{class_record_instance_ptr} = &$widget->{class_record_instance};

HERE_EOF
}

main();

