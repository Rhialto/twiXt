package Resource;

# a.k.a. public or settable instance member.

use strict;
use warnings;
use Data::Dumper;
use NameUtils;
use Widget;

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

    #print "Resource::analyze self = ", Dumper($self), "\n";
    #print "Resource::analyze widget = ", Dumper($widget), "\n";

    my $l_name = $self->{field};
    my $Name = lower_case2CamelCase($l_name);
    my $name = lower_case2camelCase($l_name);
    my $Class = $self->{class};
    my $Repr = $self->{repr};

    if (! defined $Repr) {
	$Repr = $main::common_class_to_reprname{$Class};
	if (! defined $Repr) {
	    $Repr = $Class;
	}
	$self->{repr} = $Repr;
    }

    my $ctype = $self->{ctype};

    if (! defined $ctype) {
	$ctype = $main::common_reprname_to_ctype{$Repr};
	if (! defined $ctype) {
	    $ctype = $Repr;
	}
	$self->{ctype} = $ctype;
    }

    # A resource generates various things:
    # #define for resource name
    #                      class
    #                      representation
    # TODO:
    # For these 3 we can check if they are known to exist in <X11/StringDefs.h>
    my $n = "#ifndef XtN${name}\n".
            "# define XtN${name} \"${name}\"\n".
	    "#endif\n";
    my $c = "#ifndef XtC${Class}\n".
            "# define XtC${Class} \"${Class}\"\n".
	    "#endif\n";
    my $r = "#ifndef XtR${Repr}\n".
            "# define XtR${Repr} \"${Repr}\"\n".
	    "#endif\n";

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
              "        (XtPointer)($self->{init}),\n".
	      "    },\n";

    push @{$widget->{code_resources}}, [ $res, $self ];

    # A field in the instance record

    my $field = "    ${ctype} ${name};\n";

    push @{$widget->{code_instance_record}}, [ $field, $self ];
}

1;
