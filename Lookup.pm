package Lookup;

use strict;
use warnings;

use Exporter 'import'; # gives you Exporter's import() method directly
our @EXPORT = qw( funcTypedef2declaration
                  funcTypedef2definition
		  common_class_to_reprname
		  common_reprname_to_ctype
   );
our @EXPORT_OK = @EXPORT;
 
use Data::Dumper;

my %typedef2decl = (
    # From <X11/InitrinsicP.h>
    XtAcceptFocusProc => "Boolean %s(Widget /* widget */, Time * /* time */)",
    XtAllocateProc    => "void %s(WidgetClass /* widget_class */, Cardinal * /* constraint_size */, Cardinal * /* more_bytes */, ArgList /* args */, Cardinal * /* num_args */, XtTypedArgList /* typed_args */, Cardinal * /* num_typed_args */, Widget * /* widget_return */, XtPointer * /* more_bytes_return */)",
    XtAlmostProc      => "void %s(Widget /* old */, Widget /* new */, XtWidgetGeometry* /* request */, XtWidgetGeometry* /* reply */)",
    XtArgsFunc        => "Boolean %s(Widget /* widget */, ArgList /* args */, Cardinal* /* num_args */)",
    XtArgsProc        => "void %s(Widget /* widget */, ArgList /* args */, Cardinal * /* num_args */)",
    XtDeallocateProc  => "void %s(Widget /* widget */, XtPointer /* more_bytes */)",
    XtExposeProc      => "void %s(Widget /* widget */, XEvent* /* event */, Region /* region */)",
    XtGeometryHandler => "XtGeometryResult %s(Widget /* widget */, XtWidgetGeometry* /* request */, XtWidgetGeometry* /* reply */)",
    XtInitProc        => "void %s(Widget /* request */, Widget /* new */, ArgList /* args */, Cardinal * /* num_args */)",
    XtProc            => "void %s(void)",
    XtRealizeProc     => "void %s(Widget /* widget */, XtValueMask* /* mask */, XSetWindowAttributes* /* attributes */)",
    XtSetValuesFunc   => "Boolean %s(Widget /* old */, Widget /* request */, Widget /* new */, ArgList /* args */, Cardinal* /* num_args */)",
    XtStringProc      => "void %s(Widget /* widget */, String /* str */)",
    XtWidgetClassProc => "void %s(WidgetClass /* class */)",
    XtWidgetProc      => "void %s(Widget /* widget */)",

    # <X11/Intrinsic.h> has some more:
    XtActionHookProc         => 'void %s( Widget /* w */, XtPointer /* client_data */, String /* action_name */, XEvent* /* event */, String* /* params */, Cardinal* /* num_params */)',
    XtActionProc             => 'void %s( Widget /* widget */, XEvent* /* event */, String* /* params */, Cardinal* /* num_params */)',
    XtBlockHookProc          => 'void %s( XtPointer /* client_data */)',
    XtCallbackProc           => 'void %s( Widget /* widget */, XtPointer /* closure */, /* data the application registered */ XtPointer /* call_data */ /* callback specific data */)',
    XtCancelConvertSelectionProc => 'void %s( Widget /* widget */, Atom* /* selection */, Atom* /* target */, XtRequestId* /* receiver_id */, XtPointer /* client_data */)',
    XtCaseProc               => 'void %s( Display* /* display */, KeySym /* keysym */, KeySym* /* lower_return */, KeySym* /* upper_return */)',
    XtConvertArgProc         => 'void %s( Widget /* widget */, Cardinal* /* size */, XrmValue* /* value */)',
    XtConvertSelectionIncrProc => 'Boolean %s( Widget /* widget */, Atom* /* selection */, Atom* /* target */, Atom* /* type */, XtPointer* /* value */, unsigned long* /* length */, int* /* format */, unsigned long* /* max_length */, XtPointer /* client_data */, XtRequestId* /* receiver_id */)',
    XtConvertSelectionProc   => 'Boolean %s( Widget /* widget */, Atom* /* selection */, Atom* /* target */, Atom* /* type_return */, XtPointer* /* value_return */, unsigned long* /* length_return */, int* /* format_return */)',
    XtCreatePopupChildProc   => 'void %s( Widget /* shell */)',
    XtDestructor             => 'void %s( XtAppContext /* app */, XrmValue* /* to */, XtPointer /* converter_data */, XrmValue* /* args */, Cardinal* /* num_args */)',
    XtErrorHandler           => 'void %s( String /* msg */)',
    XtErrorMsgHandler        => 'void %s( String /* name */, String /* type */, String /* class */, String /* default */, String* /* params */, Cardinal* /* num_params */)',
    XtEventDispatchProc      => 'Boolean %s( XEvent* /* event */)',
    XtEventHandler           => 'void %s( Widget /* widget */, XtPointer /* closure */, XEvent* /* event */, Boolean* /* continue_to_dispatch */)',
    XtExtensionSelectProc    => 'void %s( Widget /* widget */, int* /* event_types */, XtPointer* /* select_data */, int /* count */, XtPointer /* client_data */)',
    XtFilePredicate          => 'Boolean %s( String /* filename */)',
    XtInputCallbackProc      => 'void %s( XtPointer /* closure */, int* /* source */, XtInputId* /* id */)',
    XtKeyProc                => 'void %s( Display* /* dpy */, _XtKeyCode /* keycode */, Modifiers /* modifiers */, Modifiers* /* modifiers_return */, KeySym* /* keysym_return */)',
    XtLanguageProc           => 'String %s( Display* /* dpy */, String /* xnl */, XtPointer /* client_data */)',
    XtLoseSelectionIncrProc  => 'void %s( Widget /* widget */, Atom* /* selection */, XtPointer /* client_data */)',
    XtLoseSelectionProc      => 'void %s( Widget /* widget */, Atom* /* selection */)',
    XtResourceDefaultProc    => 'void %s( Widget /* widget */, int /* offset */, XrmValue* /* value */)',
    XtSelectionCallbackProc  => 'void %s( Widget /* widget */, XtPointer /* closure */, Atom* /* selection */, Atom* /* type */, XtPointer /* value */, unsigned long* /* length */, int* /* format */)',
    XtSelectionDoneIncrProc  => 'void %s( Widget /* widget */, Atom* /* selection */, Atom* /* target */, XtRequestId* /* receiver_id */, XtPointer /* client_data */)',
    XtSelectionDoneProc      => 'void %s( Widget /* widget */, Atom* /* selection */, Atom* /* target */)',
    XtSignalCallbackProc     => 'void %s( XtPointer /* closure */, XtSignalId* /* id */)',
    XtTimerCallbackProc      => 'void %s( XtPointer /* closure */, XtIntervalId* /* id */)',
    XtTypeConverter          => 'Boolean %s( Display* /* dpy */, XrmValue* /* args */, Cardinal* /* num_args */, XrmValue* /* from */, XrmValue* /* to */, XtPointer* /* converter_data */)',
    XtWorkProc               => 'Boolean %s( XtPointer /* closure */ /* data the application registered */)',
);

# This function returns an expanded typedef, if we know it at least.
# This is mostly used to be able to declare functions, given a typedef name
# that describes a pointer to them.

sub funcTypedef2declaration
{
    my ($name, $default) = @_;

    my $format = $typedef2decl{$name};

    if (!defined $format) {
	#warn "Function typedef '$name' is unknown";
	$format = $default;
    }

    return $format;
}

sub funcTypedef2definition
{
    my ($name, $default) = @_;

    my $format = funcTypedef2declaration($name, $default);

    # Uncover the parameter names by removing the comment symbols
    $format =~ s=/\*==g;
    $format =~ s=\*/==g;

    return $format;
}

# Some helper functions to generate the lookup table.
# Fortunately the X11 header files have a really nice layout.

my %collected;

sub parseX11header
{
    my $filename = $_[0];

    open my $header, "<", $filename;

    while (<$header>) {
	chomp;

	# typedef Boolean (*XtConvertSelectionProc)(
	if (/^typedef \w+ \(\*(\w+)\)\($/) {
	    my $name = $1;

	    my $lines = $_;
	    $lines =~ s/\(\*$name\)/%s/;
	    $lines =~ s/^typedef //;

	    for (;;) {
		my $nextline = <$header>;
		chomp $nextline;

		if ($nextline eq ");") {
		    $lines .= ")";
		    last;
		}

		$lines .= " ".$nextline;
	    }

	    $lines =~ s/[ \t]+/ /g;

	    $collected{$name} = $lines;
	}
    }
}

if ($0 eq "Lookup.pm" && $ARGV[0] eq "parse") {
    parseX11header("/usr/X11R7/include/X11/Intrinsic.h");
    parseX11header("/usr/X11R7/include/X11/IntrinsicP.h");

    #print Dumper(\%collected), "\n";
    for my $k (sort keys %collected) {
	printf "    %-24s => '%s',\n", $k, $collected{$k};
    }
}

# Only needs to contain the non-identity mappings.
# No XtR will be prepended.
my %common_class_to_reprname = (
    Depth  => "Int",
    Background => "XtRColor",
    Accelerators => "XtRAcceleratorTable",
    Translations => "XtRTranslatorTable",
);

# Each resource type name (which is a string) has a corresponding
# C type which implements it. Usually this is the name without its
# initial XtR. TwiXt usually spells it without this prefix anyway.
# This hash contains the exceptions (from intrinsics.pdf chapter 9, page 142)
my %common_reprname_to_ctype = (
    AcceleratorTable => "XtAccelerators",
    Bitmap           => "Pixmap",	# depth = 1
    Callback         => "XtCallbackList",
    Color            => "XColor",
    CommandArgArray  => "String *",
    DirectoryString  => "String",
    Display          => "Display *",
    Enum             => "XtEnum",
    EnvironmentArray => "String *",
    File             => "FILE *",
    Float            => "float",
    FontStruct       => "XFontStruct *",
    Function         => "(*)()",
    Geometry         => "char *",	# format as defined by XParseGeometry
    Gravity          => "int",
    InitialState     => "int ",
    Int              => "int",
    LongBoolean      => "long",
    Pointer          => "XtPointer",
    RestartStyle     => "unsigned char",
    Screen           => "Screen *",
    Short            => "short",
    SmcConn          => "XtPointer",
    StringArray      => "String *",
    StringTable      => "String *",
    TranslationTable => "XtTranslations",

    EditMode         => undef,
    Justify          => undef,
    Orientation      => undef,

    CallProc         => undef,	# typedef void (*XtResourceDefaultProc)(Widget w, int offset, XrmValue *value)
    Immediate        => undef,
);

sub common_class_to_reprname 
{
    my $Class = $_[0];

    my $Repr = $common_class_to_reprname{$Class};
    if (! defined $Repr) {
	$Repr = $Class;
    }

    return $Repr;
}

sub common_reprname_to_ctype
{
    my $Repr = $_[0];

    my $ctype = $common_reprname_to_ctype{$Repr};
    if (! defined $ctype) {
	$ctype = $Repr;
    }

    return $ctype;
}

1;
