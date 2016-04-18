package Widget;

use strict;
use warnings;
use NameUtils;

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
	print "First Analyzing $super before $self->{Name}\n";
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

	my $init_self = "";
	my $init_subclass = "";

	if (defined $superclass) {
	    $init_self     = $superclass->{code_init_subclass};
	    $init_subclass = $superclass->{code_init_subclass};
	}

	$init_self .= "    { /* init_self $self->{Name} */\n";
	foreach my $m (@$mems) {
	    $init_self .= $m->{code_init_self};
	}
	$init_self .= "    }, /* $self->{Name} */\n";

	$self->{code_init_self} = $init_self;

	$init_subclass .= "    { /* init_subclass $self->{Name} */\n";
	foreach my $m (@$mems) {
	    $init_subclass .= $m->{code_init_subclass};
	}
	$init_subclass .= "    }, /* $self->{Name} */\n";

	$self->{code_init_subclass} = $init_subclass;
    }

    # Analyze instance_members (type Resource and PrivateInstanceMember)
    if (defined (my $mems = $self->{instance_members})) {
	foreach my $m (@$mems) {
	    $m->analyze($self);
	}

    }
}

1;
