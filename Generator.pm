package Generator;

use strict;
use warnings;

#use Data::Dumper;

use Widget;

use Exporter 'import'; # gives you Exporter's import() method directly
our @EXPORT = qw(generate_all);
our @EXPORT_OK = @EXPORT;

sub generate_all
{
    my $allwidgets = $_[0];

    for my $key (sort keys %{$allwidgets}) {
        generate_one($allwidgets->{$key});
    }
}

sub generate_one
{
    (my Widget $widget) = @_;

    if ($widget->{generate_level} > 0) {
        my $donotedit =
            "/*\n".
            " * Do not edit this file.\n".
            " * It has been generated by TwiXt\n".
            " * from widget description $widget->{sourcefilename}.\n".
            " */";


        generate_public_h_file($widget, $donotedit);
        generate_private_h_file($widget, $donotedit);
        generate_c_file($widget, $donotedit);
    }
}

sub generate_public_h_file
{
    (my Widget $widget, my $donotedit) = @_;

    #print "generate_public_h_file: widget = ", Dumper($widget), "\n";

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

    my $top_file = $widget->{code_blocks}->{top_h_file}->{body} || "";
    my $bottom_file = $widget->{code_blocks}->{bottom_h_file}->{body} || "";

    my $rootclass = $widget->rootclass();

    open my $file, ">", $Public_h_file_name;
    print $file <<HERE_EOF;
${donotedit}
#ifndef ${NAME}_H
#define ${NAME}_H

#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>

${top_file}
/* Resource names */
${xtns}
/* Resource classes */
${xtcs}
/* Resource representation types */
${xtrs}

/* Class record pointer */
extern WidgetClass $widget->{class_record_instance_ptr};

/* C Widget type definition */
typedef struct $widget->{class_record_type} *${Name}WidgetClass;
typedef struct $widget->{instance_record_type} *${Name}Widget;

/* New class method entry points */

${bottom_file}
#endif /* ${NAME}_H */
HERE_EOF
    close $file;
}

sub generate_private_h_file
{
    (my Widget $widget, my $donotedit) = @_;

    my $Private_h_file_name = $widget->{Private_h_file_name};
    my $NAME = $widget->{NAME};
    my $name = $widget->{name};
    my $l_name = $widget->{l_name};
    my $Name = $widget->{Name};

    my $superinclude = "";

    my $superclass = $widget->{superclass};

    if (defined $superclass) {
        $superinclude =
            "/* Include private header of superclass */\n".
            "#include <$superclass->{Private_h_file_name}>";
    }

    my $all_fields = "";

    if (exists $widget->{code_instance_record}) {
        for my $m (@{$widget->{code_instance_record}}) {
            $all_fields .= $m->[0];
        }
    }

    my $class_extensions = "";

    if (defined $widget->{class_extensions}) {
        my ClassExtension $e;
        for $e (values %{$widget->{class_extensions}}) {
            $class_extensions .= $e->{code_struct_decl};
        }
    }

    my $top_file = $widget->{code_blocks}->{top_ph_file}->{body} || "";
    my $bottom_file = $widget->{code_blocks}->{bottom_ph_file}->{body} || "";

    open my $file, ">", $Private_h_file_name;
    print $file <<HERE_EOF;
${donotedit}
#ifndef ${NAME}P_H
#define ${NAME}P_H

#include <X11/IntrinsicP.h>

/* Include public header */
#include <$widget->{Public_h_file_name}>

${superinclude}

${top_file}
/* New representation types used by the ${Name} widget */

/* Declarations for class functions */
$widget->{declare_class_functions}

/* Defines for inheriting superclass function pointer values */
$widget->{inherit_defines}

/* New fields for the ${Name} instance record */
typedef struct {
    /* Settable resources and private data */
${all_fields}
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

/* Class extension records */
${class_extensions}

/* Full class record declaration */
typedef struct $widget->{class_record_type} {
$widget->{all_class_part_instance_decls}
} $widget->{class_record_type};

extern struct $widget->{class_record_type} $widget->{class_record_instance};

${bottom_file}
#endif /* ${NAME}P_H */
HERE_EOF
    close $file;
}

sub generate_c_file
{
    (my Widget $widget, my $donotedit) = @_;

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

    my $top_file = $widget->{code_blocks}->{top_c_file}->{body} || "";
    my $bottom_file = $widget->{code_blocks}->{bottom_c_file}->{body} || "";

    my $rootclass = $widget->rootclass();

    open my $file, ">", $c_file_name;
    print $file <<HERE_EOF;
${donotedit}

#include <stddef.h>
#include <$widget->{Private_h_file_name}>

${top_file}
/******************************************************************
 *
 * $Name Resources
 *
 ******************************************************************/

static XtResource resources[] = {
${all_resources}
};

struct $widget->{class_record_type} $widget->{class_record_instance} = {
$widget->{code_init_self}
};

/*
 * Declare this as WidgetClass instead of the "more real" types
 *
 *     $widget->{class_record_type} * or $rootclass->{class_record_type} *,
 *
 * because Xt functions such as XtCreateWidget() take an argument of that type.
 *
 * The definition of WidgetClass in <X11/Core.h> is
 *
 *     typedef struct _WidgetClassRec *CoreWidgetClass;
 *
 * where Widget is a strange alias of Core.
 */
WidgetClass $widget->{class_record_instance_ptr} = (WidgetClass)&$widget->{class_record_instance}.$rootclass->{l_name}_class;

/* Definitions for class functions */
$widget->{define_class_functions}

${bottom_file}
HERE_EOF
    close $file;
}
