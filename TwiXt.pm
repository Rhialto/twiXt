package TwiXt;

use strict;
use warnings;

use parent 'Parser::MGC';
#use Data::Dumper;
use ClassField;
use ClassOverride;
use CodeBlock;
use NameUtils;
use PrivateInstanceField;
use Resource;
use Utils ('hashed_list_of_hashes', 'trim');
use Widget;

sub parse
{
    my TwiXt $self = $_[0];

    $self->skip_ws();

    my $widgets = $self->list_of( qr/;/,
	sub { $self->widget() }
    );

    return hashed_list_of_hashes("Name", $widgets);
}

####
#
# Parse a widget:
#
# widget FooWidget : Core {
# 	... class overrides
# 	... class field definitions
# 	... instance field definitions
# };
#
sub widget
{
    my TwiXt $self = $_[0];

    $self->expect("widget");

    my $name = $self->ident_camelcase();

    my $super;
    my $hassuper = $self->maybe_expect(qr/:/);
    if ($hassuper) {
	$super = $self->ident_camelcase();
    }

    $self->commit();

    my $block = $self->block_scope_of( sub {
	$self->widget_block();
    } );

    my Widget $widget = Widget->new(
	Name             => $name,
	super            => $super,
	%{$block}
    );

    return $widget;
}

sub widget_block
{
    my TwiXt $self = $_[0];
    my Widget %found;

    # Allow code_definition, class_override, class_field_definitions,
    # instance_field_definitions in any order, and the first two can occur
    # multiple times.
    $self->sequence_of( sub {
	$self->any_of(
	    sub {
		my $code = $self->code_definition();
		my $name = $code->{name};
		$found{code_blocks}->{$name} = $code;
	    },
	    sub {
		my $override = $self->class_override();
		my $name = $override->{name};
		$found{class_overrides}->{$name} = $override;
	    },
	    sub {
	        if ($found{class_fields}) {
		    $self->fail();
		}
		my %flags;
		$found{class_fields} = $self->class_field_definitions(\%flags);
		$found{no_inherit_class_fields} = defined $flags{no_inherit};
	    },
	    sub {
		if ($found{instance_fields}) {
		    $self->fail();
		}
		$found{instance_fields} = $self->instance_field_definitions();
	    },
	);
    } );

    return \%found;
}

sub code_definition
{
    my TwiXt $self = $_[0];

    $self->expect("code");
    my $label = $self->token_string();

    $self->commit();

    $self->expect(qr/\{\{\{/);
    # Annoyingly, substring_before will stop before the } which
    # is the end of the current scope.
    # Hack this to disable that.
    local $self->{endofscope} = undef;
    my $body = $self->substring_before(qr/\}\}\}/);
    $body = trim($body);
    $self->expect(qr/\}\}\}/);
    
    return new CodeBlock(
	name => $label,
	body => $body,
    );
}

# Several blocks of overrides are allowed:
# one block per superclass, each block can contain
# multiple fields in the superclass record to override.

sub class_override
{
    my TwiXt $self = $_[0];

    $self->expect("override");
    $self->commit();

    my $overridden = $self->ident_camelcase();

    my $fields = $self->block_scope_of( sub {
	$self->sequence_of ( sub {
	    $self->class_field_override()
	} )
    } );

    return ClassOverride->new(
	name   => $overridden,
	fields => hashed_list_of_hashes("field", $fields),
    );
}

sub class_field_override
{
    my TwiXt $self = $_[0];

    my $parts = $self->all_of(
	sub { $self->ident_lowercase() },
	sub { $self->expect(qr/=/) },
	sub { $self->substring_before(qr/;/) },
	sub { $self->expect(qr/;/) },
    );

    return {
	field => $parts->[0],
	init  => $parts->[2],
    };
}

sub class_field_definitions
{
    my TwiXt $self = $_[0];
    my $flags = $_[1];

    $self->expect("class");
    $self->commit();

    $flags->{no_inherit} = $self->maybe_expect(qr/no-inherit/);

    $self->block_scope_of( sub {
	$self->sequence_of ( sub {
	    $self->class_field_definition()
	} )
    } );
}

sub class_field_definition
{
    my TwiXt $self = $_[0];

    my $decl = $self->c_declaration();
    my $init_self;
    my $init_subclass;

    if ($self->maybe_expect(qr/;/)) {
	# ok, no initialisation then.
	$init_self     = "0";
	$init_subclass = "0";
    } else {
	if ($self->maybe_expect(qr/=/)) {
	    $self->skip_ws();
	    $init_self = $self->substring_before(qr/;/);
	    $init_self = trim($init_self);
	    $self->expect(qr/;/);
	} else {
	    $init_self = "0";
	}

	if ($self->maybe_expect("sub=")) {
	    $self->skip_ws();
	    $init_subclass = $self->substring_before(qr/;/);
	    $init_subclass = trim($init_subclass);
	    $self->expect(qr/;/);
	} else {
	    $init_subclass = $init_self;
	}
    }

    my $comment = $self->maybe_comment();

    return ClassField->new(
	%{$decl},
	init_self     => $init_self,
	init_subclass => $init_subclass,
	comment       => $comment,
    );
}

# Fields can be resources (and then they are settable via
# XtSetValues() etc, or just private.
# The order is relevant, because we want to be able to describe
# the existing widgets in a compatible way.

sub instance_field_definitions
{
    my TwiXt $self = $_[0];

    $self->expect("instance");
    $self->commit();

    $self->block_scope_of( sub {
	$self->sequence_of ( sub {
	    $self->any_of(
		sub { $self->resource_definition(); },
		sub { $self->private_field_definition(); }
	    )
	} )
    } );
}

#  public: Pixel(Color) background = (Black + White) / 2;
#  public: Int(Int) testint : int = 3;
#  public: Type(Class) resource_name : resource_sizeoftype @offset =R(default_type) default_addr;
#  How to put in resource_offset, optionally? Defaults to the field
#  resource_name in instance record.

sub resource_definition
{
    my TwiXt $self = $_[0];

    my $class = undef;
    my $init = undef;
    my $ctype = undef;
    my $default_type = "XtRImmediate";
    my $offset = undef;

    #$self->expect(qr/public/);
    my $kw = $self->token_kw(qw(public resource));
    $self->expect(qr/:/);
    $self->commit();

    my $is_resource_only = ($kw eq "resource");

    my $repr = $self->ident_camelcase();
    if ($self->maybe_expect(qr/\(/)) {
	$class = $self->ident_camelcase();
	$self->expect(qr/\)/);
    }
    my $field = $self->ident_lowercase();

    if ($self->maybe_expect(qr/:/)) {
	$self->skip_ws();
	$ctype = $self->substring_before(qr/[@=;]/);
	$ctype = trim($ctype);
    }

    if ($is_resource_only && $self->maybe_expect(qr/@/)) {
	$self->skip_ws();
	$offset = $self->substring_before(qr/[=;]/);
	$offset = trim($offset);
    }

    my $has_init = 0;
    # =R(FooType)
    if (my $string = $self->maybe_expect(qr/=R\(([A-Za-z0-9]+)\)/)) {
	$string =~ /=R\(([A-Za-z0-9]+)\)/;
	$default_type = "XtR".$1;
	$has_init++;
    } elsif ($self->maybe_expect(qr/=/)) {
	$default_type = "XtRImmediate";
	$has_init++;
    }

    if ($has_init) {
	$self->skip_ws();
	$init = $self->substring_before(qr/;/);
	$init = trim($init);

	length $init or $self->fail( "Expected a C initializer expression ';'" );

	if ($init =~ s/\(\)$//) {
	    $default_type = "XtRCallProc";
	}
    } else {
	$init = "0";
    }

    $self->expect(qr/;/);

    my $comment = $self->maybe_comment();

    return Resource->new(
	field        => $field,
	repr         => $repr,
	class        => $class,
	ctype        => $ctype,
	default_type => $default_type,
	default_addr => $init,
	offset       => $offset,
	comment      => $comment,
    );
}

sub private_field_definition
{
    my TwiXt $self = $_[0];

    $self->expect("private:");
    $self->commit();

    my $decl = $self->c_declaration();

    $self->expect(qr/;/);

    my $comment = $self->maybe_comment();

    return PrivateInstanceField->new(
	%{$decl},
	comment => $comment,
    );
}

# Parse a C declaration, including stuff like
# unsigned short int (*fp)(int, int);
#
# We can cheat a bit, since the first identifier in the rhs
# is the variable name.
# A CamelCase identifier is assumed to be a type name.
# The variable/field name must be lower_case.

sub c_declaration
{
    (my TwiXt $self) = @_;

    my $qualifiers = $self->sequence_of( sub {
	    $self->token_kw(qw(const volatile))
	});

    my $declaratortype;

    $self->maybe(sub {
	    my $token = $self->token_kw(qw(struct union));
	    my $tag = $self->token_ident();
	    $declaratortype = $token." ".$tag;
	});
    if (defined $declaratortype) {
	# struct/union part matched
    } else {
	my $basictypes = $self->sequence_of( sub {
		$self->token_kw(qw(signed unsigned long short char int float double void))
	    });
	if (@{$basictypes}) {
	    $declaratortype = join(" ", @$basictypes);
	} else {
	    # Here assume that for instance "XtWidgetProc" is a typedef.
	    my $id = $self->ident_camelcase();
	    if (defined $id) {
		$declaratortype = $id;
	    } else {
		$self->fail("No type in C declaration");
	    }
	}
    }

    if (@$qualifiers) {
	my $cv = join(" ", @$qualifiers);
	$declaratortype = $cv." ".$declaratortype;
    }

    $self->skip_ws();
    my $declarator = $self->substring_before(qr/[=;]/);
    $declarator = trim($declarator);

    my $id;
    my $declarator_pattern;

    # Find the identifier in the rhs.
    # It is the first thing that looks like an identifier and is
    # not const or volatile.
    # (Also skip things starting with _ in case they are weird keywords)
    while ($declarator =~ /([a-zA-Z0-9_]+)/gp) {
	my $matched = $1;
	next if $matched eq "const";
	next if $matched eq "volatile";
	next if substr($matched, 0, 1) eq "_"; # don't spoil ^PREMATCH: don't use a regexp.
	$id = $matched;
	$declarator_pattern = ${^PREMATCH}."%s".${^POSTMATCH};
	last;
    }
    if (!defined $declarator_pattern) {
	warn "c_declaration: Can't find id in declarator $declarator\n";
    }

    my $declaration = $declaratortype." ".$declarator;
    my $declaration_pattern = $declaratortype." ".$declarator_pattern;

    return {
	declaration             => $declaration,
	declaration_pattern     => $declaration_pattern,
	declaration_specifiers  => $declaratortype,
	declarator              => $declarator,
	field                   => $id,
    };
}

# Meta-rule
sub block_scope_of
{
    (my TwiXt $self, my $code) = @_;

    my $result = $self->scope_of( qr/{/, $code, qr/}/ );

    # $self->maybe_expect(qr/;/);

    return $result;
}

# Meta-rule
# Expect all of the code refs in sequence and return a reference to a
# list containing their results.
# XXX Doesn't do fancy commit handling.
sub all_of_try_1
{
    (my TwiXt $self, my @codes) = @_;

    my @result = ();

    for my $code (@codes) {
	push @result, $self->$code();
    }

    return \@result;
}

# A merge between any_of and list_of
sub all_of #_try_2
{
    my TwiXt $self = shift;
    my @ret = ();

    while (@_ && !$self->at_eos) {
	my $code = shift;
	my $pos = pos $self->{str};

	my $committed = 0;
	local $self->{committer} = sub { $committed++ };

	eval { push @ret, $self->$code; 1 } and next;
	my $e = $@;

	pos( $self->{str} ) = $pos;
	die $e if $committed or not Parser::MGC::_isa_failure( $e );
	
	last;
    }
    continue {
	$self->skip_ws;
    }

    return \@ret;
}

# CamelCase
sub ident_camelcase
{
    my TwiXt $self = $_[0];

    my $token = $self->token_ident();

    if (! is_CamelCase($token)) {
	$self->fail("Identifier should be CamelCase");
    }

    return $token;
}

# lower_case
sub ident_lowercase
{
    my TwiXt $self = $_[0];

    my $token = $self->token_ident();

    if (! is_lower_case($token)) {
	$self->fail("Identifier should be lower_case");
    }

    return $token;
}

sub maybe_comment
{
    my TwiXt $self = $_[0];

    my $comment;

    if ($self->maybe_expect(qr=/\*=)) {
	my $text = $self->substring_before(qr=\*/=);
	$self->expect(qr=\*/=);

	$comment = "/*$text*/";
    }

    return $comment;
}

1;
