/*
 * Some sample code to start up an application using something other
 * than the default visual, and to test some widget by placing it in
 * a toplevel window.
 *
 * To compile:
 *	cc -g main.c Joystick.c -o joystick -lXaw -lXmu -lXt -lXext -lX11 -lm
 *
 * To run:
 *	./joystick -geometry 300x300 -depth 24 -visual StaticColor -fg blue -bg yellow
 *
 * you need to move the mouse to get the particular visuals colormap
 * to install.
 *
 * You can also override widget properties in your .Xresources file,
 * in a file in app-defaults, or with
 *
 * 	./joystick -xrm "widgetTest.form.joystick1.borderWidth:5" \
		   -xrm "WidgetTest.Form.Joystick.borderColor:red" \
		   -xrm "WidgetTest.Form.Joystick.background:purple"
 *
 * Note how the more specific (e.g. instance name instead of class name)
 * setting wins.
 */

#include <stdio.h>

#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>
#include <X11/Shell.h>
#include <X11/Xaw/Form.h>

#include "Joystick.h"

typedef struct
{
	Visual	*visual;
	int	depth;
} OptionsRec;

OptionsRec	Options;

XtResource resources[] =
{
    {"visual", "Visual", XtRVisual, sizeof (Visual *),
	XtOffsetOf (OptionsRec, visual), XtRImmediate, NULL},
    {"depth", "Depth", XtRInt, sizeof (int),
	XtOffsetOf (OptionsRec, depth), XtRImmediate, NULL},
};

XrmOptionDescRec Desc[] =
{
    {"-visual", "*visual", XrmoptionSepArg, NULL},
    {"-depth", "*depth", XrmoptionSepArg, NULL}
};

String fallback_resources[] = {
    "WidgetTest.Form.joystick1.width: 32",
    "WidgetTest.Form.joystick1.height: 32",

    "WidgetTest.Form.joystick2.width: 64",
    "WidgetTest.Form.joystick2.height: 64",
    "WidgetTest.Form.joystick2.background: yellow",
    "WidgetTest.Form.joystick2.borderWidth: 0",
    NULL,
};

struct TimerCtx {
    XtAppContext app_context;
    Widget joy1, joy2;
    int counter;
    Pixel blue, pink;
};

struct TimerCtx ctx;

/*
 * Every so often this function gets called.
 *
 * This makes the program somewhat active when the tested widgets
 * don't do that by themselves.
 */
void TimerCallbackProc(XtPointer client_data, XtIntervalId *timer)
{
    struct TimerCtx    *ctx = (struct TimerCtx *)client_data;
    Arg			args[2];
    int			cnt;

    //fprintf(stderr, "TimerCallbackProc\n");

    cnt = 0;

    XtSetArg(args[cnt], XtNenableBits, ctx->counter); ++cnt;
    XtSetValues(ctx->joy1, args, cnt);

    /* quickly modify the value in-place */
    args[cnt-1].value = ~ctx->counter;

    if ((ctx->counter % 10) == 0) {
	Pixel color = (ctx->counter % 20) ? ctx->pink : ctx->blue;

	XtSetArg(args[cnt], XtNdirectionColor, color); cnt++;
    }

    XtSetValues(ctx->joy2, args, cnt);

    ctx->counter++;

    /* Re-arm the timer */
    XtAppAddTimeOut(ctx->app_context, 666, TimerCallbackProc, client_data);
}




int
main (int argc, char **argv)
{
    XtAppContext	app;		/* the application context */
    Widget		top;		/* toplevel widget */
    Display	       *dpy;		/* display */
    char	      **xargv;		/* saved argument vector */
    int			xargc;		/* saved argument count */
    Colormap		colormap;	/* created colormap */
    XVisualInfo		vinfo;		/* template for find visual */
    XVisualInfo	       *vinfo_list;	/* returned list of visuals */
    int			count;		/* number of matchs (only 1?) */
    Arg			args[10];
    Cardinal		cnt;
    char	       *name = "widgetTest";
    char	       *class = "WidgetTest";
    Widget		form;
    Widget		joy1, joy2;
    XColor		screen_def, exact_def;

    /*
     * save the command line arguments
     */

    xargc = argc;
    xargv = (char **) XtMalloc (argc * sizeof (char *));
    bcopy ((char *) argv, (char *) xargv, argc * sizeof (char *));

    /*
     * The following creates a _dummy_ toplevel widget so we can
     * retrieve the appropriate visual resource.
     */
    cnt = 0;
    top = XtOpenApplication(&app, class, Desc, XtNumber(Desc), &argc, argv,
			    fallback_resources, applicationShellWidgetClass,
			    args, cnt);
    dpy = XtDisplay (top);
    cnt = 0;
    XtGetApplicationResources(top, &Options, resources,
			      XtNumber (resources),
			      args, cnt);
    cnt = 0;
    if (Options.visual && Options.visual != DefaultVisualOfScreen(XtScreen(top))) {
	XtSetArg(args[cnt], XtNvisual, Options.visual); ++cnt;
	/*
	 * Now we create an appropriate colormap.  We could
	 * use a default colormap based on the class of the
	 * visual; we could examine some property on the
	 * rootwindow to find the right colormap; we could
	 * do all sorts of things...
	 */
	colormap = XCreateColormap(dpy,
				   RootWindowOfScreen(XtScreen(top)),
				   Options.visual,
				   AllocNone);
	XtSetArg(args[cnt], XtNcolormap, colormap); ++cnt;

	/*
	 * Now find some information about the visual.
	 */
	vinfo.visualid = XVisualIDFromVisual(Options.visual);
	vinfo_list = XGetVisualInfo(dpy, VisualIDMask, &vinfo, &count);

	if (vinfo_list && count > 0) {
	    XtSetArg(args[cnt], XtNdepth, vinfo_list[0].depth);
	    ++cnt;
	    XFree((XPointer) vinfo_list);
	}
    } else {
	colormap = DefaultColormapOfScreen(XtScreen(top));
    }
    XtDestroyWidget (top);

    /*
     * Now create the real toplevel widget.
     */
    XtSetArg(args[cnt], XtNargv, xargv); ++cnt;
    XtSetArg(args[cnt], XtNargc, xargc); ++cnt;

    top = XtAppCreateShell(name, class,
			   applicationShellWidgetClass,
			   dpy, args, cnt);

    /*
     * Add a Form into the toplevel, so we can put
     * some of the widgets into it that we really wanted to test.
     *
     * Note how parameters such as XtNwidth or XtNbackground are not
     * needed since they are in the fallback_resources.
     */
    form = XtVaCreateManagedWidget("form",
				   formWidgetClass, top,
				   NULL);

    joy1 = XtVaCreateManagedWidget("joystick1",
				   joystickWidgetClass, form,
				   /* Constraints */
				   NULL);

    joy2 = XtVaCreateManagedWidget("joystick2",
				   joystickWidgetClass, form,
				   XtNenableBits, 31,
				   /* Constraints */
				   XtNfromHoriz, joy1,
				   NULL);
    /*
     * Allocate some colours for changing the widget appearance.
     */
    XAllocNamedColor(dpy, colormap, "blue",
		     &screen_def, &exact_def);
    ctx.blue = screen_def.pixel;

    XAllocNamedColor(dpy, colormap, "hotpink",
		     &screen_def, &exact_def);
    ctx.pink = screen_def.pixel;

    ctx.joy1 = joy1;
    ctx.joy2 = joy2;
    ctx.counter = 0;
    ctx.app_context = app;

    XtAppAddTimeOut(app, 666, TimerCallbackProc, &ctx);

    /*
     * Display the application and loop handling all events.
     */
    XtRealizeWidget(top);
    XtAppMainLoop(app);

    return 0;
}

