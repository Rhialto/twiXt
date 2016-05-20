package ClassExtension;

use strict;
use warnings;
use Data::Dumper;
use Widget;
use fields qw(
    code_struct_decl
    fields
    name
    version
);

# A ClassExtension object:
#
# {
# 	name => "QuarkName",
# 	fields => [
# 		    ClassField, ...
# 		  ]
# 	code_class_decl => "int foo; long bar;"
# }
sub new
{
    (my $class, my @fields) = @_;

    bless { @fields }, $class;
}

sub analyze
{
    (my ClassExtension $self, my Widget $widget) = @_;

    my $fields   = $self->{fields};
    my $name     = $self->{name}    // "";
    my $name1    = $self->{name}    // "NULLQUARK";
    my $version  = $self->{version} // "";
    my $version1 = $self->{version} // "1";
    my $Class    = $widget->{Name};


    my $decl_fields = $widget->analyze_class_fields($fields);

    $name = "" if $name eq "NULLQUARK";

    $self->{code_struct_decl} = <<EOT;
typedef struct  {
    XtPointer next_extension;   /* 1st 4 required for all extension records */
    XrmQuark record_type;       /* ${name1}; when on ${Class}ClassPart */
    long version;               /* must be ${Class}Extension${name}${version}Version */
    Cardinal record_size;       /* sizeof(${Class}ClassExtension${name}${version}Rec) */
${decl_fields}
} ${Class}ClassExtension${name}${version}Rec, *${Class}ClassExtension${name}${version};

#define ${Class}Extension${name}${version}Version ${version1}

EOT

}

1;
