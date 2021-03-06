package Widget;

use strict;
use warnings;
use ClassExtension;
use ClassField;
use ClassOverride;
use NameUtils;
use Data::Dumper;
use fields qw(
    all_class_part_instance_decls
    all_instance_part_instance_decls
    analyzed
    class_extensions
    class_fields
    class_overrides
    class_part_instance_decl
    class_record_instance
    class_record_instance_ptr
    class_record_part_type
    class_record_type
    code_blocks
    code_class_decl
    code_init_self
    code_instance_record
    code_resources
    code_xtc
    code_xtn
    code_xtr
    c_file_name
    declare_class_functions
    define_class_functions
    generate_level
    inherit_defines
    instance_fields
    instance_part_instance_decl
    instance_part_type
    instance_record_type
    l_name
    NAME
    Name
    name
    no_inherit_class_fields
    Private_h_file_name
    Public_h_file_name
    sourcefilename
    super
    superclass
);

sub new
{
    (my $class, my @fields) = @_;

    bless { @fields }, $class;
}

sub analyze
{
    (my Widget $self, my $allwidgets) = @_;

    return if (exists $self->{analyzed});

    my $super = $self->{super};
    my $superclass;

    # Analyze the superclass first, if necessary.
    if (defined $super) {
	if (exists $allwidgets->{$super}) {
	    $superclass = $allwidgets->{$super};
	    $self->{superclass} = $superclass;

	    #print "First Analyzing $superclass->{Name} before $self->{Name}\n";
	    $superclass->analyze($allwidgets);
	} else {
	    warn "Superclass ${super} of $self->{Name} not defined.";
	}
    }

    print "Analyzing $self->{Name}";
    print " (no code generation)" if $self->{generate_level} <= 0;
    print "\n";

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
    $self->{class_record_instance_ptr} = $name."WidgetClass";

    # Calculate (super)class record declarations

    $self->{class_part_instance_decl} =
	"    $self->{class_record_part_type} ${l_name}_class;\n";
    $self->{instance_part_instance_decl} =
	"    $self->{instance_part_type} ${l_name};\n";

    $self->{all_class_part_instance_decls} = "";
    $self->{all_instance_part_instance_decls} = "";

    if (defined $superclass && ! $self->{no_inherit_class_fields}) {
	$self->{all_class_part_instance_decls} =
	    $superclass->{all_class_part_instance_decls} . $self->{class_part_instance_decl};
    } else {
	$self->{all_class_part_instance_decls} =
	    $self->{class_part_instance_decl};
    }

    if (defined $superclass) {
	$self->{all_instance_part_instance_decls} =
	    $superclass->{all_instance_part_instance_decls} . $self->{instance_part_instance_decl};
    } else {
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

    # Analyze class_fields (type ClassField)
    if (defined (my $fields = $self->{class_fields})) {
	$self->{code_class_decl} = $self->analyze_class_fields($fields);

	$self->{code_init_self} = $self->
	    analyze_init_class($self, $self->{class_overrides});
    }

    # Analyze class_extensions which have more ClassFields
    if (defined (my $extens = $self->{class_extensions})) {
	my ClassExtension $e;

	foreach $e (values %$extens) {
	    $e->analyze($self);
	}
    }

    # Analyze instance_fields (type Resource and PrivateInstanceField)
    if (defined (my $fields = $self->{instance_fields})) {
	foreach my $f (@$fields) {
	    $f->analyze($self);
	}
    }
}

# This is used from Widget but also from ClassExtension.
# Loop through all ClassFields and call their analyze().
# Then loop again and collect the text that was created for the
# declaration of these fields.
sub analyze_class_fields
{
    my Widget $widget = $_[0];
    my $fields = $_[1];

    return unless defined $fields;

    my ClassField $f;

    foreach $f (@$fields) {
	$f->analyze($widget);
    }

    my $classdecl = "";
    foreach $f (@$fields) {
	$classdecl .= $f->{code_class_decl};
    }

    return $classdecl;
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
    my Widget $superclass = $self->{superclass};

    if (defined $superclass && ! $self->{no_inherit_class_fields}) {
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

    my $mems = $self->{class_fields};
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

#    print "analyze_init_with_field: $self->{Name} for $for_class->{Name}; overrides:\n",
#	    Dumper($overrides), "\n";

    my $code = "    { /* $self->{Name} for $for_class->{Name} */\n";
    foreach my $m (@$mems) {
	my $field = $m->{field};
	my $value;

	if (defined $overfields && exists $overfields->{$field}) {
	    $value = $overfields->{$field}->{init};
	} else {
	    $value = $m->{$init};
	}
	$value = $for_class->expand_pattern($value);
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

# Expand pattern:
# %c	class
# %s	superclass
#
# with modifiers (before the c, s, or f)
# none	CamelCase
# _	lower_case	%_c
# l	camelCase	%ls

sub expand_pattern
{
    (my Widget $self, my $pattern) = @_;

    #print STDERR "expand_pattern: pattern = $pattern\n";

    if ($pattern =~ /%/) {
	my $result = "";

	while ($pattern =~ /%([_l]?)([cs%])/p) {
	    $result .= ${^PREMATCH};
	    my $format = ${^MATCH}; # $&;
	    $pattern = ${^POSTMATCH};	# for next iteration

	    my $modifier    = $1 // "";
	    my $valueletter = $2;

	    #print STDERR "rest pattern= $pattern\n";
	    #print STDERR "format      = $format\n";
	    #print STDERR "result      = $result\n";
	    #print STDERR "valueletter = $valueletter; modifier = $modifier\n";

	    if ($format eq "%%") {
		$result .= "%";
	    } else {
		my $replacement = "";


		if ($valueletter eq "c") {
		    $replacement = $self->{Name};
		} elsif ($valueletter eq "s") {
		    if (defined $self->{superclass}) {
			$replacement = $self->{superclass}->{Name};
		    } else {
			$replacement = $self->{Name};
		    }
		}

		#print STDERR "replacement1 = $replacement\n";
		if ($modifier eq "l") {
		    $replacement = CamelCase2camelCase($replacement);
		} elsif ($modifier eq "_") {
		    $replacement = CamelCase2lower_case($replacement);
		}
		#print STDERR "replacement2 = $replacement\n";

		$result .= $replacement;
	    }

	}

	$result .= $pattern;

	return $result;
    } else {
	return $pattern;
    }
}

# Finds an initialisation, given a field name and the class it's in.
# Takes base class overrides into account.
#
# TODO: this has lots of overlap with sub analyze_init_with_field.

sub find_class_field_init_by_name
{
    (my Widget $self, my $class_name, my $field_name) = @_;

    # First look at overrides

    my ClassOverride $over = $self->{class_overrides}->{$class_name};

    if (defined $over) {
	my $init = $over->{fields}->{$field_name}->{init};

	if (defined $init) {
	    # If it contains a pattern, plug in the class name
	    $init = $self->expand_pattern($init);

	    return $init;
	}
    }

    my Widget $superclass = $self->is_subclass_of($class_name);

    if (defined $superclass) {
	#print STDERR "find_class_field_init_by_name: $class_name::$field_name\n";
	#print STDERR Dumper($superclass->{class_fields}), "\n";

	foreach my ClassField $class_field (@{$superclass->{class_fields}}) {
	    if ($class_field->{field} eq $field_name) {
		my $init;

		# if ($superclass->{Name} eq $self->{Name}) { }
		if ($superclass == $self) {
		    $init = $class_field->{init_self};
		} else {
		    $init = $class_field->{init_subclass};
		}
		# If it contains a pattern, plug in the class name
		$init = $self->expand_pattern($init);

		return $init;
	    }
	}
    }

    return undef;
}

if ($0 eq __FILE__ && @ARGV > 0 && $ARGV[0] eq "test") {
    my $widget = Widget->new(
	Name => "ClassName",
	superclass => Widget->new(
	    Name => "SuperClass",
	)
    );

    print STDERR $widget->expand_pattern("CamelCase:  %%c  %c  %%s  %s\n");
    print STDERR $widget->expand_pattern("camelCase:  %%lc %lc  %%ls %ls\n");
    print STDERR $widget->expand_pattern("lower_case: %%_c %_c %%_s %_s\n");

    exit 0;
}

1;
