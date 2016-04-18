package Generator;

use strict;
use warnings;

use Data::Dumper;

use Widget;

use Exporter 'import'; # gives you Exporter's import() method directly
our @EXPORT = qw(generate_all);
our @EXPORT_OK = @EXPORT;

sub generate_all
{
    my $hash = $_[0];

    my $key;
    my $value;

    while (($key, $value) = each %$hash) {
	generate_one($value, $hash);
    }
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

    if (defined $widget->{code_xtn}) {
	for my $m (@{$widget->{code_xtn}}) {
	    $xtns .= $m->[0];
	}
    }

    if (defined $widget->{code_xtc}) {
	for my $m (@{$widget->{code_xtc}}) {
	    $xtcs .= $m->[0];
	}
    }

    if (defined $widget->{code_xtr}) {
	for my $m (@{$widget->{code_xtr}}) {
	    $xtrs .= $m->[0];
	}
    }

    open FILE, ">", $Public_h_file_name;
    print FILE <<HERE_EOF;
#ifndef ${NAME}_H
#define ${NAME}_H

#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>

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

    my $superinclude = "";

    my $super = $allwidgets->{$widget->{super}} if defined $widget->{super};

    if (defined $super) {
	$superinclude =
	    "/* Include private header of superclass */\n".
	    "#include <$super->{Private_h_file_name}>";
    }

    my $all_fields = "";

    if (exists $widget->{code_instance_record}) {
	for my $m (@{$widget->{code_instance_record}}) {
	    $all_fields .= $m->[0];
	}
    }

    open FILE, ">", $Private_h_file_name;
    print FILE <<HERE_EOF;
#ifndef ${NAME}P_H
#define ${NAME}P_H

/* Include public header */
#include <$widget->{Public_h_file_name}>

${superinclude}

/* New representation types used by the ${Name} widget */

/* New fields for the ${Name} instance record */
typedef struct {
/* Settable resources */
${all_fields}
/* Data derived from resources */
     // TODO
} $widget->{instance_part_type};

/* Full instance record declaration */
typedef struct $widget->{instance_record_type} {
$widget->{all_instance_part_instance_decls}
} $widget->{instance_record_type};

/* Types for ${Name} class methods */

/* New fields for the ${Name} class record */
typedef struct {
$widget->{code_class_decl}
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
    my ($widget, $allwidgets) = @_;

    my $c_file_name = $widget->{c_file_name};
    my $NAME = $widget->{NAME};
    my $name = $widget->{name};
    my $l_name = $widget->{l_name};
    my $Name = $widget->{Name};

    my $all_resources = "";

    if (defined $widget->{code_resources}) {
	for my $m (@{$widget->{code_resources}}) {
	    $all_resources .= $m->[0];
	}
    }

    open FILE, ">", $c_file_name;
    print FILE <<HERE_EOF;

#include <stddef.h>
#include <$widget->{Private_h_file_name}>

/******************************************************************
 *
 * $Name Resources
 *
 ******************************************************************/

static XtResource resources[] = {
${all_resources}
};

static struct $widget->{class_record_type} $widget->{class_record_instance} = {
$widget->{code_init_self}
};

$widget->{class_record_type} *$widget->{class_record_instance_ptr} = &$widget->{class_record_instance};

HERE_EOF
}
