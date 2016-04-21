package Widget;

use strict;
use warnings;
use NameUtils;
use Data::Dumper;

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

    my $super = $self->{super};
    my $superclass;

    if (defined $super && exists $allwidgets->{$super}) {
	$superclass = $allwidgets->{$super};
	$self->{superclass} = $superclass;
    }

    if (defined $superclass) {
	print "First Analyzing $superclass->{Name} before $self->{Name}\n";
	$superclass->analyze($allwidgets);
    }

    print "Analyzing $self->{Name}\n";

    $self->{analyzed}++;

    my $Name = $self->{Name};

    my $NAME = anycase2UPPERCASE($Name);
    my $name = CamelCase2camelCase($Name);
    my $l_name = CamelCase2lower_case($Name);

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

    if (defined $superclass) {
	$self->{all_class_part_instance_decls} =
	    $superclass->{all_class_part_instance_decls} . $self->{class_part_instance_decl};
	$self->{all_instance_part_instance_decls} =
	    $superclass->{all_instance_part_instance_decls} . $self->{instance_part_instance_decl};
    } else {
	$self->{all_class_part_instance_decls} =
	    $self->{class_part_instance_decl};
	$self->{all_instance_part_instance_decls} =
	    $self->{instance_part_instance_decl};
    }

    $self->{inherit_defines} = "";
    $self->{declare_class_functions} = "";
    $self->{define_class_functions} = "";

    # Analyze class_overrides
    if (defined (my $overs = $self->{class_overrides})) {
	foreach my $o (values %$overs) {
	    $o->analyze($self);
	}
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

	my $classdecl = "";
	foreach my $m (@$mems) {
	    $classdecl .= $m->{code_class_decl};
	}

	$self->{code_class_decl} = $classdecl;

	$self->{code_init_self} = $self->
	    analyze_init_class($self, $self->{class_overrides});
    }

    # Analyze instance_members (type Resource and PrivateInstanceMember)
    if (defined (my $mems = $self->{instance_members})) {
	foreach my $m (@$mems) {
	    $m->analyze($self);
	}

    }
}

# Generate some code to initialize the class fields of a class.
#
# There are a few cases:
# There can be different initial values for a field when it is used
# as the final class, or when it is used as a base class.
# In the second case, there can be specific overrides in the final
# class.
#
sub analyze_init_class
{
    (my Widget $self, my Widget $for_class, my $overrides) = @_;

    my $superclasses;
    my $superclass = $self->{superclass};

    if (defined $superclass) {
	$superclasses = $superclass->analyze_init_class(
				    $for_class, $overrides);
    } else {
	$superclasses = "";
    }

    my $thisclass = $self->analyze_init_with_field($for_class,
					    $overrides->{$self->{Name}});

    return $superclasses.$thisclass;
}

sub analyze_init_with_field
{
    (my Widget $self, my Widget $for_class, my $overrides) = @_;

    my $mems = $self->{class_members};
    my $init;

    if ($self->{Name} eq $for_class->{Name}) {
	$init = "init_self";
    } else {
	$init = "init_subclass";
    }

    my $overfields;
    if (defined $overrides) {
	$overfields = $overrides->{fields};
    }

    print "analyze_init_with_field: $self->{Name} for $for_class->{Name}; overrides:\n",
	    Dumper($overrides), "\n";

    my $code = "    { /* $self->{Name} for $for_class->{Name} */\n";
    foreach my $m (@$mems) {
	my $field = $m->{field};
	my $value;

	if (defined $overfields && exists $overfields->{$field}) {
	    $value = $overfields->{$field}->{init};
	} else {
	    $value = $m->{$init};
	}
	if ($value =~ /%/) {
	    $value = sprintf $value, $for_class->{Name};
	}
	$code .= sprintf $m->{code_init_pattern}, $value;

	$m->analyze_function_pointer($self, $for_class, $value);
    }
    $code .= "    }, /* $self->{Name} */\n";

    return $code;
}

sub superclass
{
    (my Widget $self) = @_;

    return $self->{superclass};
}

sub rootclass
{
    (my Widget $self) = @_;

    my $rootclass = $self;

    while (1) {
	my $parent = $rootclass->{superclass};
	if (! defined $parent) {
	    return $rootclass;
	}
	$rootclass = $parent;
    }
}

sub is_subclass_of
{
    (my Widget $self, my $maybe_parent) = @_;

    if ($self->{Name} eq $maybe_parent) {
	return $self;
    }

    my $superclass = $self->{superclass};

    if (!defined $superclass) {
	return undef;
    }

    return $superclass->is_subclass_of($maybe_parent);
}

1;
