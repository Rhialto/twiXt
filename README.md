TwiXt - Templated Widgets for Xt
================================

TwiXt is intended to make it easier to write widgets for X, using the X
Toolkit Intrinsics. Doing so by hand is not really difficult, but it is
a bit tedious, since C is not really object-oriented, but the widgets
are based on classes with single inheritance.

If you specify a widget (class) named FooThing, TwiXt will generate for
you the public header file `FooThing.h`, the private header file
`FooThingP.h`, and the top part of `FooThing.c`, with the definitions of
the resource records, the class record and functions that have pointers
to them. 

TwiXt uses all naming conventions that the Xt and Xaw widgets as far as
possible. It turns out that in some cases those widgets themselves
deviate from their own conventions. In that case, TwiXt attempts to have
a mechanism to specify that kind of exception to the rules.

Because C does not have a class system built-in, this is instead
implemented in the Intrinsics library. This makes use of a
user-specified collection of fields (or sometimes called members) that
make up the class. Those fields are basically common for all instances
of the widget.

Then there are the fields that exist once for each widget instance.
Therefore the outline of a widget description generally looks like this:

<pre><code>
widget Name : BaseClass {
    class {
        # fields ...
    }
    instance {
        # fields ...
    }
};
</code></pre>

For more details on this, please see the X Toolkit Intrinsics
documentation.  TwiXt aims to make use of Xt easier, but fully
explaining it is beyond its scope.

See [Free O'Reilly books](http://www.x.org/wiki/ProgrammingDocumentation/) and
[the X.org website](http://www.x.org/releases/X11R7.7/doc/index.html#client-devel).

Class fields
------------

The class fields are always private, i.e. are only under control of the
widget's code (and the Intrinsics library of course), and not accessible
to the user's code.  Instance fields on the other hand, can potentially
be accessed by the user. This is the case for the fields that correspond
to a Resource. In addition to those, there can of course also be private
fields.

<pre><code>
    class {
        WidgetClass superclass = (WidgetClass)&unnamedObjClassRec; sub= (WidgetClass)&%lsClassRec; 
                                                          /* pointer to superclass ClassRec   */
        String      class_name = "%c";                    /* widget resource class name       */
        Cardinal    widget_size = sizeof(%cRec);          /* size in bytes of widget record   */
        XtProc      class_initialize = %cClassInitialize; /* class initialization proc        */
        # ...
    }
</code></pre>

Class field descriptions look very much like normal C declarations.
There are some general conventions:

- C types are spelled in CamelCase (starting with an uppercase letter).
- field names are spelled in lower_case (with underscores).

Where needed, these forms can seamlessly be converted into each other.

A field description can optionally include initalization values in two
variants: one for class records in the class implementation itself,
(started with `=`) and one proposed to implementations of subclasses
(start with `sub=`).
These can be overriden if desired.

If no class expression is given, it usually defaults to 0.
If no subclass expression is given, it defaults to the class expression.

TwiXt doesn't really analyze the structure of you expressions (the C
compiler will complain later if you write nonsense),
but there is some pattern expansion to fill in class names.

- `%c` will be replaced by the `ClassName` of the class where it is used.
- `%s` will be replaced by the `ClassName` of the superclass.
- `%lc` and `%ls` will be that name, with a lowercase initial
- `%_c` and `%_s` will be that name, in `lower_cased` form.

Using these expansions can help you to propose appropriate function
names in subclasses that are unique and descriptive.

Following the class field, you can put a C-style comment.
It will be copied into the generated source.
These comments are only possible in designated locations.
TwiXt-style comments are allowed anywhere. They start with a hash symbol
`#` and continue to the end of the line.

For class fields that represent a C function pointer (i.e. their type
name ends in `Proc`, `Func`, `Handler` or `Converter`), a declaration
for the corresponding function is generated, and also a template for a
definition (with empty function body).

### Class field overrides

When a subclass is created, the superclass' fields are included in the
subclass. As mentioned, by default they get the value as proposed by its
own class. However you can override that with an `override` block before
your own `class` block (because that is the order in which the full class
record is generated):

<pre></code>
class SubClass : BaseClass {
    override BaseClass {
        # We would like a different value for our version of the
        # class field BaseClass.classfield_int.
        classfield_int = 99;
    }
    class {
        # ...
</code></pre>

It is checked that `BaseClass` is indeed a superclass of the current
widget, an that `classfield_int` is one of its class fields.
The same class name expansions are available for the value here too.

Instance fields
---------------

As mentioned, instance fields can potentially be accessed by the user.
This is the case for the fields that correspond to a Resource. In
addition to those, there can of course also be private fields.
Here are some examples of both cases:

<pre></code>
widget Root {
    instance {
        private: Widget         self;               /* pointer to widget itself */
        public:  Pixel(BorderColor) border_color
                  =R(String) "XtDefaultForeground"; /* window border pixel      */
</code></pre>

Private fields are the simplest. They are much like a C field
declaration. There is not even an initial value like with class fields,
because there is no static instance defined. The `initialize` function
pointer (inherited from the `Core` widget) is meant to set fields in a
new instance to their initial values.

Public fields are a bit more involved, since they basically are a
combination of an instance field and a resource description. The latter
conststs of 7 parts but fortunately you can usually leave some of them
out.

Resources consist of the following parts:

- resource_name:
  The name to use with XtSetValues() and XtGetValues() to access
  the resource. This is in principle an arbitrary string, but
  conventionally it is in camelCase (lower case initial).
  An instance field with lower_case name is also generated from this
  name.
  To prevent typos in the name, a `#define` is generated with the same
  name: `XtN`_resourceName_.  

  In the example, this is border_color.

- resource_class:
  Not to be confused with "class" as in the meaning of "type", but
  a name to group multiple related resources together. The aim is that
  the user can easily set all Background-related colours to the same
  value in a resource file. Resource classes are spelled in CamelCase
  (upper case initial).
  To prevent typos in the name, a `#define` is generated with the same
  name: `XtN`_ClassName_.

  In the example, this is BorderColor.

- resource_type:
  This is the name of the type which represents the value of the
  resource. Xt type converters know of these names to convert for
  instance strings into the correct values.
  To prevent typos in the name, a `#define` is generated with the same
  name: `XtR`_ResourceType_.

  In the example, this is Pixel.

- resource_size:
  This is the size of objects of type `resource_type`. Normally this
  is derived from the `resource_type` field. If you want to make an
  exception, use `: ctypename` after the `resource_name`. This type is
  then also used in generating the instance field.

- resource_offset:
  This describes where in the instance record the resource is located.
  It is pretty much always derived automatically from the instance field
  (which in turn is derived from `resource_name`).  
  In the rare cases that you have a resource which does not have a
  one-to-one correspondence with an instance field, use this
  construction as seen in the CoreWidget:
  <pre><code>
    private:  XtTMRec       tm;                 /* translation management  */
    resource: TranslationTable(Translations) translations <b>@tm.translations</b>
                     =R(TranslationTable) NULL; /* translation management  */
   </code></pre>

  Here, the instance contains a `XtTMRec` structure, and the resource
  refers to one if its internal fields.
  By using the `resource` keyword instead of `public`, you indicate
  that no field is generated to go with the resource. Use an
  appropriate other field instead. It also allows the use of the `@`
  which is not allowed for `public`.

- default_type:
  Resources can be initialized by the resource system automatically.
  This field specifies the type of `default_addr`.

  In the example, this is `String` (transformed into `XtRString`).

  There is special syntax for the special types
    * `XtRImmediate` (which copies the value without converting it):
      just use a simple `=` sign
    * `XtRCallProc` (which calls a function of signature
      [`XtResourceDefaultProc`](http://www.x.org/releases/X11R7.7/doc/libXt/intrinsics.html#XtResourceDefaultProc)): use `= FunctionName()`.

- default_addr:
  This should point to an appropriate value of the type named by
  `default_type`.

  In the example, this is `"XtDefaultForeground"`.

Summarizing, a resource description that uses no defaults would look
like

    resource: ResourceType(ResourceClass) resource_name :resource_size_type @resource_offset
                     =R(DefaultType) default_addr;

For more details, see [chapter 9 "Resource Management" of the Intrinsics
document](http://www.x.org/releases/X11R7.7/doc/libXt/intrinsics.html#Resource_Management).

{>>
 vim:expandtab:ft=markdown:
<<}

