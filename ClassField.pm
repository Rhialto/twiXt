package ClassField;

use strict;
use warnings;
use Data::Dumper;
use CodeBlock;
use Widget;
use NameUtils;
use Lookup;
use fields qw(
    code_class_decl
    code_init_pattern
    comment
    declaration
    declaration_pattern
    declaration_specifiers
    declarator
    field
    init_self
    init_subclass
);
#   With a field description such as
#   void (*funcptr)(int, int), then
#
# declaration			= void (*funcptr)(int, int)
# declaration_pattern		= void (*%s)(int, int)
# declaration_specifiers	= void
# declarator			= (*funcptr)(int, int)
# field				= funcptr

sub new
{
    (my $class, my @fields) = @_;

    bless { @fields }, $class;
}

#
# This is called for every classfield while analyzing its class.
# Also called for fields in class extension records.
#

sub analyze
{
    (my ClassField $self, my Widget $widget) = @_;

    #print "ClassField::analyze, before: ", Dumper($self), "\n";
    my $comment = $self->{comment} || "";

    # Test if this is an own field or an override for a superclass field
    if (exists $self->{field}) {
	$self->{code_class_decl} =
	"    ".$self->{declaration}."; $comment\n";

	$self->{code_init_pattern} =
	"    .".$self->{field}." = %s, $comment\n";

	my $type = $self->is_function_pointer();

	# For function pointers, create a #define to inherit it from
	# the parent class. There is a default name for this define,
	# "XtInherit${Field}",
	# but if a simple subclass initializer is given, use that as a name.

	if (defined $type) {
	    my $field = $self->{field};
	    my $Field = lower_case2CamelCase($field);
	    my $Class = $widget->{Name};
	    my $init_subclass = $self->{init_subclass};

	    # If type is a pattern, make it into a cast
	    if ($type =~ /%/) {
		$type = sprintf $type, "";
	    }

	    # Is this a good idea?
	    # and if so, should it be here?
	    if (!defined $init_subclass || $init_subclass eq "") {
		$self->{init_subclass} = $init_subclass = "%c".$Field;
		warn "Setting default init function for $Field: $init_subclass()";
	    }

	    # If it contains a pattern, plug in the class name
	    $init_subclass = $widget->expand_pattern($init_subclass);

	    my $defname = "XtInherit${Field}";
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

            # Create boilerplate code in the class_part_initialize
            # function to actually inherit from the superclass.
            # Only if it has a superclass, of course.
            # This generates a few too many fragments, for silly things
            # you don't want to inherit anyway.

            if (defined $widget->superclass()) {
                my Widget $rootclass = $widget->rootclass();
                my $classinitfuncname =
                    $widget->find_class_field_init_by_name($rootclass->{Name}, "class_part_initialize");

                if (defined $classinitfuncname) {
                    my CodeBlock $cb = $widget->{code_blocks}->{$classinitfuncname};

                    if (!defined $cb) {
                        my $body = "    ${Class}Rec *self, *super;\n\n".
                                   "    self = (${Class}Rec *) class;\n".
                                   "    super = (${Class}Rec *) class->$rootclass->{l_name}_class.superclass;\n\n";
                        $cb = new CodeBlock(name => $classinitfuncname,
                                            body => $body);
                        $widget->{code_blocks}->{$classinitfuncname} = $cb;
                        #print STDERR "code_blocks $classinitfuncname: $body";
                    }

                    my $body = "    if (self->$widget->{l_name}_class.$field == $defname)\n".
                               "        self->$widget->{l_name}_class.$field = super->$widget->{l_name}_class.$field;\n\n";

                    $cb->append($body);
                    #print STDERR "code_blocks append $classinitfuncname: $body";

                } else {
                    #print STDERR "No inherit code for $defname\n";
                }
            } else {
                #print STDERR "No inherit code for root class $Class\n";
            }
	}
    }

    #print "ClassField::analyze, after ", Dumper($self, $widget), "\n";
}

# Returns a defined value (the type) if the class field is
# recognizably a function pointer.
# That is the case for type names ending in Proc|Func|Handler|Converter,
# but also if they look like (*...)(...).
# That is a somewhat sloppy test but for now it seems good enough.

sub is_function_pointer
{
    my ClassField $self = $_[0];

    #print STDERR "ClassField::is_function_pointer: ", Dumper($self), "\n";
    my $type = $self->{declaration_specifiers};

    # declaration_specifiers =>  'WidgetProc'
    # declarator             =>  'ptr'
    # declaration_pattern    =>  'WidgetProc %s'
    if ($type =~ /(Proc|Func|Handler|Converter)$/) {
	#print STDERR "yes: $type\n";
	# return something that is not undef and will be recognized
	# by funcTypedef2declaration().
	return $type;
    }
    # NOTE: WidgetProc *foo is NOT a function pointer.

    # declaration_specifiers =>  'void'
    # declarator             =>  '(*funcptr)(int, int)'
    # declaration_pattern    =>  'void (*%s)(int, int)'
    my $declarator = $self->{declarator};
    if ($declarator =~ /^\(\*.*\)\(.*\)$/) {
	#print STDERR "yes: $self->{declaration_pattern}\n";
	return $self->{declaration_pattern};
	# Unrecognized by funcTypedef2declaration, so the default will be used
	# (which happens to be declaration_pattern)
	# and the * pointer will be removed.
    }

    #print STDERR "no.\n";
    return undef;
}

#
# This is called multiple times for each ClassField:
# once for each instantiation, which means it will be called for its own
# class and for each of the subclasses which include it.
#

sub analyze_function_pointer
{
    (my ClassField $self, my Widget $widget, my Widget $for_class, my $value) = @_;

    my $type = $self->is_function_pointer();

    if (defined $type) {
	# Pre-declare and define the function, if needed and appropriate.
	if ($value !~ /Inherit/ && is_CamelCase($value)) {
	    # Declaration: FooFunc %s(int, long)
	    my $pat = funcTypedef2declaration($type, $self->{declaration_pattern});
	    my $declare = sprintf $pat, $value;

	    $for_class->{declare_class_functions} .= "extern ${declare};\n";


	    # Definition: FooFunc %s(int i, long l)
	    $pat = funcTypedef2definition($type, $self->{declaration_pattern});
	    my $define = sprintf $pat, $value;
            my $body = $for_class->{code_blocks}->{$value}->{body} //
                       $widget->{code_blocks}->{$value}->{body} //
                       "";

	    $for_class->{define_class_functions} .= "${define}\n{\n${body}\n}\n\n";
	}
    }
}

1;
