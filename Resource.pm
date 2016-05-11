package Resource;

# a.k.a. public or settable instance field.

use strict;
use warnings;
use Data::Dumper;
use Lookup;
use NameUtils;
use Widget;
use fields qw(
    comment
    class
    ctype
    default_type
    default_addr
    field
    repr
    offset
);

sub new
{
    (my $class, my @fields) = @_;

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
	$Repr = common_class_to_reprname($Class);
	$self->{repr} = $Repr;
    }

    my $ctype = $self->{ctype};

    if (! defined $ctype) {
	$ctype = common_reprname_to_ctype($Repr);
	$self->{ctype} = $ctype;
    }

    # The offset key is optional; only used when resource setting doesn't use a
    # simple variable. In that case, generating the instance field is
    # suppressed.
    my $offset = $self->{offset} // $l_name;

    my $comment = $self->{comment} // "";

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

    # Prefix the widget's own instance Part unless overridden.
    if ($offset =~ s/^://) {
	# Use as-is (but without the leading colon).
    } else {
	$offset = $widget->{l_name}.".".${offset};
    }

    # A structure for resource init and get/set
    my $res = "    { $comment\n".
              "        .resource_name   = XtN${name},\n".
              "        .resource_class  = XtC${Class},\n".
              "        .resource_type   = XtR${Repr},\n".
              "        .resource_size   = sizeof (${ctype}),\n".
              "        .resource_offset = XtOffsetOf($widget->{instance_record_type}, ${offset}),\n".
              "        .default_type    = $self->{default_type},\n".
              "        .default_addr    = (XtPointer)($self->{default_addr}),\n".
	      "    },\n";

    push @{$widget->{code_resources}}, [ $res, $self ];

    # A field in the instance record.
    # Do we need to implement {ctype} as a sprintf-pattern too?

    if (! defined $self->{offset}) {
	my $field = "    ${ctype} ${l_name}; $comment\n";

	push @{$widget->{code_instance_record}}, [ $field, $self ];
    }
}

1;
