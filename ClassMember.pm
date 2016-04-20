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

	my $type = $self->{declaration_specifiers};

	# For function pointers, create a #define to inherit it from
	# the parent class. There is a default name for this define,
	# "${Class}Inherit${Field}",
	# but if a simple subclass initializer is given, use that as a name.
	if ($type =~ /(Proc|Func|Handler|Converter)$/) {
	    my $field = $self->{field};
	    my $Field = lower_case2CamelCase($field);
	    my $Class = $widget->{Name};
	    my $init_subclass = $self->{init_subclass};
	    my $init_self = $self->{init_self};

	    my $defname = "${Class}Inherit${Field}";
	    my $defval  = "((${type}) _XtInherit)";

	    if ($init_subclass =~ /Inherit/ &&
		is_CamelCase($init_subclass)) {
		$defname = $init_subclass;
	    }

	    my $define = "#define $defname $defval\n";

	    $widget->{inherit_defines} .= $define;

	    print "DEFINE: $define";

	    # Pre-declare and define the function.
	    if (is_CamelCase($init_self)) {
		# Declaration
		my $pat = funcTypedef2declaration($type, $self->{declaration_pattern});
		my $declare = sprintf $pat, $init_self;

		$widget->{declare_class_functions} .= "extern ${declare};\n";


		# Definition
		$pat = funcTypedef2definition($type, $self->{declaration_pattern});
		my $define = sprintf $pat, $init_self;

		$widget->{define_class_functions} .= "${define}\n{\n}\n\n";
	    }
	}
    }

    #print "ClassMember::analyze, after ", Dumper($self, $widget), "\n";
}

1;
