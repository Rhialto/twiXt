package ClassMember;

use strict;
use warnings;
use Data::Dumper;
use Widget;
use NameUtils;
use Lookup;

sub new
{
    my $class;
    my @fields;
    ($class, @fields) = @_;

    # init_self
    # init_subclass
    # declaration			void (*funcptr)(int, int)
    # declaration_pattern		void (*%s)(int, int)
    # declaration_specifiers		void
    # declarator			(*funcptr)(int, int)
    # field
    #
    # With a field description such as
    # void (*funcptr)(int, int), then
    #
    bless { @fields }, $class;
}

#
# This is called for every classmember while analyzing its class.
#

sub analyze
{
    (my ClassMember $self, my Widget $widget) = @_;

    #print "ClassMember::analyze, before: ", Dumper($self), "\n";
    # Test if this is an own field or an override for a superclass field
    if (exists $self->{field}) {
	$self->{code_class_decl} =
	"        ".$self->{declaration}.";\n";

	$self->{code_init_pattern} =
	"        .".$self->{field}." = %s,\n";

	my $type = $self->is_function_pointer();

	# For function pointers, create a #define to inherit it from
	# the parent class. There is a default name for this define,
	# "${Class}Inherit${Field}",
	# but if a simple subclass initializer is given, use that as a name.

	if (defined $type) {
	    my $field = $self->{field};
	    my $Field = lower_case2CamelCase($field);
	    my $Class = $widget->{Name};
	    my $init_subclass = $self->{init_subclass};

	    # Is this a good idea?
	    # and if so, should it be here?
	    if (!$init_subclass) { # undef or "0" or the like
		$self->{init_subclass} = $init_subclass = "%s".$Field;
	    }

	    # If it contains a pattern, plug in the class name
	    if ($init_subclass =~ /%/) {
		$init_subclass = sprintf $init_subclass, $Class;
	    }

	    my $defname = "${Class}Inherit${Field}";
	    my $defval  = "((${type}) _XtInherit)";

	    if ($init_subclass =~ /Inherit/ &&
		is_CamelCase($init_subclass)) {
		$defname = $init_subclass;
	    }

	    my $define = "#ifndef $defname\n".
	                 "# define $defname $defval\n".
			 "#endif\n";

	    $widget->{inherit_defines} .= $define;

	    #print "DEFINE: $define";
	}
    }

    #print "ClassMember::analyze, after ", Dumper($self, $widget), "\n";
}

sub is_function_pointer
{
    my ClassMember $self = $_[0];

    my $type = $self->{declaration_specifiers};

    if ($type =~ /(Proc|Func|Handler|Converter)$/) {
	return $type;
    }

    return undef;
}

#
# This is called multiple times for each ClassMember:
# once for each instantiation, which means it will be called for its own
# class and for each of the subclasses which include it.
#

sub analyze_function_pointer
{
    (my ClassMember $self, my Widget $widget, my Widget $for_class, my $value) = @_;

    my $type = $self->is_function_pointer();

    if (defined $type) {
	my $field = $self->{field};
	my $Field = lower_case2CamelCase($field);
	my $Class = $widget->{Name};

	# Pre-declare and define the function, if needed and appropriate.
	if ($value !~ /Inherit/ && is_CamelCase($value)) {
	    # Declaration: FooFunc %s(int, long)
	    my $pat = funcTypedef2declaration($type, $self->{declaration_pattern});
	    my $declare = sprintf $pat, $value;

	    $for_class->{declare_class_functions} .= "extern ${declare};\n";


	    # Definition: FooFunc %s(int i, long l)
	    $pat = funcTypedef2definition($type, $self->{declaration_pattern});
	    my $define = sprintf $pat, $value;

	    $for_class->{define_class_functions} .= "${define}\n{\n}\n\n";
	}
    }
}
1;
