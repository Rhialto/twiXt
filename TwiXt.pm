package TwiXt;

use strict;
use warnings;

use parent 'Parser::MGC';
#use Data::Dumper;
use ClassMember;
use ClassOverride;
use Resource;
use Widget;
use Utils ('hashed_list_of_hashes');

sub parse
{
    my $self = $_[0];

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
# 	... class member definitions
# 	... instance member definitions
# };
#
sub widget
{
    my $self = $_[0];

    $self->expect("widget");

    my $name = $self->ident_camelcase();

    my $super;
    my $hassuper = $self->maybe_expect(qr/:/);
    if ($hassuper) {
	$super = $self->ident_camelcase();
    }

    $self->commit();
    my $members = $self->block_scope_of( sub {
	$self->all_of(
	    sub { $self->class_overrides(); },
	    sub { $self->class_member_definitions(); },
	    sub { $self->instance_member_definitions(); }
	)
    } );

    return Widget->new(
	Name             => $name,
	super            => $super,
	class_overrides  => $members->[0],
	class_members    => $members->[1],
	instance_members => $members->[2],
    );
}

# Several blocks of overrides:
# one block per superclass, each block can contain
# multiple fields in the superclass record to override.
sub class_overrides
{
    my $self = $_[0];

    my %overrides;

    $self->sequence_of( sub {
	$self->expect("override");
	$self->commit();

	my $overridden = $self->ident_camelcase();

	my $members = $self->block_scope_of( sub {
	    $self->sequence_of ( sub {
		$self->class_member_override()
	    } )
	} );

	$overrides{$overridden} = ClassOverride->new(
	    name   => $overridden,
	    fields => hashed_list_of_hashes("field", $members),
	);

    } );

    return \%overrides;
}

sub class_member_override
{
    my $self = $_[0];

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

sub class_member_definitions
{
    my $self = $_[0];

    $self->expect("class");
    $self->commit();

    $self->block_scope_of( sub {
	$self->sequence_of ( sub {
	    $self->class_member_definition()
	} )
    } );
}

sub class_member_definition
{
    my $self = $_[0];

    my $decl = $self->c_declaration();
    my $init_self;
    my $init_subclass;

    if ($self->maybe_expect(qr/=/)) {
	$self->skip_ws();
	$init_self = $self->substring_before(qr/;/);
	$self->expect(qr/;/);
    } else {
	$init_self = "0";
    }

    if ($self->maybe_expect("sub=")) {
	$self->skip_ws();
	$init_subclass = $self->substring_before(qr/;/);
	$self->expect(qr/;/);
    } else {
	$init_subclass = $init_self;
    }

    return ClassMember->new(
	%{$decl},
	init_self     => $init_self,
	init_subclass => $init_subclass,
    );
}

sub override_class_member
{
    my $self = $_[0];

    $self->expect("override");
    $self->expect(qr/;/);

    return ClassMember->new(
	what => "override"
    );
}

# Members can be resources (and then they are settable via
# XtSetValues() etc, or just private.
# The order is relevant, because we want to be able to describe
# the existing widgets in a compatible way.

sub instance_member_definitions
{
    my $self = $_[0];

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

sub resource_definition
{
    my $self = $_[0];

    my $class = undef;
    my $init = undef;
    my $ctype = undef;

    $self->expect(qr/public/);
    $self->expect(qr/:/);
    $self->commit();

    my $repr = $self->ident_camelcase();
    if ($self->maybe_expect(qr/(/)) {
	$class = $self->ident_camelcase();
	$self->expect(qr/)/);
    }
    my $field = $self->ident_lowercase();

    if ($self->maybe_expect(qr/:/)) {
	$self->skip_ws();
	$ctype = $self->substring_before(qr/[=;]/);
    }

    if ($self->maybe_expect(qr/=/)) {
	$self->skip_ws();
	$init = $self->substring_before(qr/;/);
	length $init or $self->fail( "Expected a C initializer expression ';'" );
    } else {
	$init = "0";
    }

    $self->expect(qr/;/);

    return Resource->new(
	field     => $field,
	repr      => $repr,
	class     => $class,
	ctype     => $ctype,
	init      => $init,
    );
}

sub private_field_definition
{
    my $self = $_[0];

    $self->expect("private:");
    $self->commit();

    my $decl = $self->c_declaration();

    $self->expect(qr/;/);

    return PrivateInstanceMember->new(
	%{$decl}
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
    (my $self) = @_;

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
	next if substr($matched, 0, 1) eq "_";
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
    my ($self, $code) = @_;

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
    my ($self, @codes) = @_;

    my @result = ();

    for my $code (@codes) {
	push @result, $self->$code();
    }

    return \@result;
}

# A merge between any_of and list_of
sub all_of #_try_2
{
    my $self = shift;
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
    my $self = $_[0];

    my $token = $self->token_ident();

    if ($token =~ /_/ || $token !~ /^[[:upper:]]/) {
	$self->fail("Identifier should be CamelCase");
    }

    return $token;
}

# lower_case
sub ident_lowercase
{
    my $self = $_[0];

    my $token = $self->token_ident();

    if ($token =~ /[[:upper:]]/) {
	$self->fail("Identifier should be lower_case");
    }

    return $token;
}

1;
