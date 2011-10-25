/* -*- mode:C; tab-width:8; c-basic-offset:8; indent-tabs-mode:true -*- */

/*
 * Mines for GNOME
 * Author:        Pista <szekeres@cyberspace.mht.bme.hu>
 *
 * Score support: horape@compendium.com.ar
 * Mine Resizing: djb@redhat.com
 *
 * This game is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307
 * USA
 */

#include <config.h>

#include <time.h>

#include <glib/gi18n.h>
#include <gtk/gtk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>

#include <libgames-support/games-runtime.h>
#include <libgames-support/games-preimage.h>

#include "minefield.h"

/* Auxillary data so we can use a single index to reference
   surrounding cells. */
static const struct {
  gint x;
  gint y;
} neighbour_map[8] = {
  {
  -1, 1}, {
  0, 1}, {
  1, 1}, {
  1, 0}, {
  1, -1}, {
  0, -1}, {
  -1, -1}, {
  -1, 0}
};

/* The colours for the numbers. The empty first entry allows us
 * to use the number as a direct index. */
static guint16 num_colors[9][3] = {
  {0x0000, 0x0000, 0x0000},	/* Black, not used */
  {0x0000, 0x0000, 0xffff},	/* Blue  */
  {0x0000, 0xa0a0, 0x0000},	/* Green */
  {0xffff, 0x0000, 0x0000},	/* Red   */
  {0x0000, 0x0000, 0x7fff},	/* Dark Blue */
  {0xa0a0, 0x0000, 0x0000},	/* Dark Red   */
  {0x0000, 0xffff, 0xffff},	/* Cyan */
  {0xa0a0, 0x0000, 0xa0a0},	/* Dark Violet */
  {0x0000, 0x0000, 0x0000}	/* Black */
};

/* The signal list for the widget. */
enum {
  MARKS_CHANGED_SIGNAL = 0,
  EXPLODE_SIGNAL,
  LOOK_SIGNAL,
  UNLOOK_SIGNAL,
  WIN_SIGNAL,
  HINT_SIGNAL,
  LAST_SIGNAL
};

/* The list of actions that can be performed when a mose button is
   pressed. */
enum {
  NO_ACTION,
  SHOW_ACTION,
  CLEAR_ACTION,
  FLAG_ACTION
};

/* Static data for the minefield class. */
static gint minefield_signals[LAST_SIGNAL];
static GtkWidgetClass *parent_class;

/*  Prototypes */
static inline gint get_cell_index_no_checks (GtkMineField * mfield, guint x,
				       guint y);
static gint get_cell_index (GtkMineField * mfield, guint x, guint y);
static void setup_sign (sign * signp, const char *file, guint minesizepixels);
static void gtk_mine_queue_draw (GtkMineField * mfield, guint x, guint y);
static gint gtk_minefield_button_press (GtkWidget * widget,
					GdkEventButton * event);
static gint gtk_minefield_button_release (GtkWidget * widget,
					  GdkEventButton * event);
static void gtk_minefield_check_field (GtkMineField * mfield, gint x, gint y);
static void gtk_minefield_class_init (GtkMineFieldClass * class);
static gboolean gtk_minefield_draw (GtkWidget * widget, cairo_t * cr);
static void gtk_minefield_init (GtkMineField * mfield);
static void gtk_minefield_lose (GtkMineField * mfield);
static gint gtk_minefield_motion_notify (GtkWidget * widget,
					 GdkEventMotion * event);
static void gtk_minefield_multi_release (GtkMineField * mfield, guint x,
					 guint y, guint c, guint really);
static void gtk_minefield_randomize (GtkMineField * mfield, int curloc);
static void gtk_minefield_realize (GtkWidget * widget);
static void gtk_minefield_setup_signs (GtkMineField * mfield);
static void gtk_minefield_show (GtkMineField * mfield, guint x, guint y);
static void gtk_minefield_size_allocate (GtkWidget * widget,
					 GtkAllocation * allocation);
static void gtk_minefield_set_mark (GtkMineField * mfield, guint x,
				    guint y, int mark);
static void gtk_minefield_toggle_mark (GtkMineField * mfield, guint x,
				       guint y);
static void gtk_minefield_unrealize (GtkWidget * widget);
static void gtk_minefield_win (GtkMineField * mfield);
static int gtk_minefield_check_cell (GtkMineField * mfield, guint x, guint y);
static void gtk_minefield_multi_press (GtkMineField * mfield, guint x,
				       guint y, gint c);
static gboolean gtk_minefield_solve_square (GtkMineField * mfield, guint x,
					    guint y, guint c);
/* end prototypes */


/* The abstraction of the coordinate system. Note that this is inline
   code that does no checking, use it sparsely. If in doubt, use
   get_cell_index instead. */
static inline gint
get_cell_index_no_checks (GtkMineField * mfield, guint x, guint y)
{
  return x + y * mfield->xsize;
}

/* Converts 2D minefield coordinates into a 1D array index. Note that
   this is used extensively for checking the validity of
   coordinates. If the coordinates are not valid then it returns
   -1. */
static gint
get_cell_index (GtkMineField * mfield, guint x, guint y)
{
  if (x < mfield->xsize && y < mfield->ysize)
    return get_cell_index_no_checks (mfield, x, y);

  return -1;
}

/* Set up a pixbuf containing an object we overlay a cell with: flags,
  mines and explosions, but not numbers. This also takes care of
  any dmemory previously allocated to the sign. This function 
  should be treated as local to gtk_minefield_setup_signs. */
static void
setup_sign (sign * signp, const char *file, guint minesizepixels)
{
  if (!signp->preimage && file != NULL)
    signp->preimage = games_preimage_new_from_file (file, NULL);

  if (signp->scaledpixbuf)
    g_object_unref (signp->scaledpixbuf);

  signp->scaledpixbuf = NULL;
  signp->width = signp->height = minesizepixels - 2;

  if (signp->preimage) {
    signp->scaledpixbuf = games_preimage_render (signp->preimage,
						 signp->width,
						 signp->height);
  }

  if (!signp->scaledpixbuf) {
    signp->scaledpixbuf = gdk_pixbuf_new (GDK_COLORSPACE_RGB,
					  TRUE, 8,
					  signp->width, signp->height);
    gdk_pixbuf_fill (signp->scaledpixbuf, 0x00000000);
    if (signp->preimage)
      g_object_unref (signp->preimage);
    signp->preimage = NULL;
  }
}

static void
gtk_minefield_setup_signs (GtkMineField * mfield)
{
  static GtkWidget *warning_dialog = NULL;
  static gchar *warning_message = NULL;
  gchar *flagfile, *minefile, *questionfile, *bangfile, *warningfile;
  const char *dname = games_runtime_get_directory (GAMES_RUNTIME_GAME_PIXMAP_DIRECTORY);

  flagfile = g_build_filename (dname, "flag.svg", NULL);
  minefile = g_build_filename (dname, "mine.svg", NULL);
  questionfile = g_build_filename (dname, "flag-question.svg", NULL);
  bangfile = g_build_filename (dname, "bang.svg", NULL);
  warningfile = g_build_filename (dname, "warning.svg", NULL);

  if ((!flagfile || !minefile || !questionfile || !bangfile || !warningfile)
      && (warning_message == NULL)) {
    warning_message =
      _
      ("Unable to find required images.\n\nPlease check your gnome-games installation.");
  }

  setup_sign (&mfield->flag, flagfile, mfield->minesizepixels);
  setup_sign (&mfield->mine, minefile, mfield->minesizepixels);
  setup_sign (&mfield->question, questionfile, mfield->minesizepixels);
  setup_sign (&mfield->bang, bangfile, mfield->minesizepixels);
  setup_sign (&mfield->warning, warningfile, mfield->minesizepixels);

  g_free(flagfile);
  g_free(minefile);
  g_free(questionfile);
  g_free(bangfile);
  g_free(warningfile);

  if ((!mfield->flag.preimage ||
       !mfield->mine.preimage ||
       !mfield->question.preimage ||
       !mfield->bang.preimage ||
       !mfield->warning.preimage) && (warning_message == NULL)) {
    warning_message =
      _
      ("Required images have been found, but refused to load.\n\nPlease check your installation of gnome-games and its dependencies.");
  }


  if (warning_message && !warning_dialog) {
    GtkWindow *parent =
      GTK_WINDOW (gtk_widget_get_toplevel (GTK_WIDGET (mfield)));
    warning_dialog =
      gtk_message_dialog_new (parent, GTK_DIALOG_MODAL, GTK_MESSAGE_ERROR,
			      GTK_BUTTONS_NONE, "%s", _("Could not load images"));

    gtk_dialog_add_button (GTK_DIALOG (warning_dialog),
			   GTK_STOCK_QUIT, GTK_RESPONSE_CLOSE);

    gtk_message_dialog_format_secondary_text (GTK_MESSAGE_DIALOG
					      (warning_dialog),
					      "%s", warning_message);
    g_signal_connect (warning_dialog, "response", G_CALLBACK (gtk_main_quit),
		      NULL);
    gtk_widget_show (warning_dialog);
  }

}

static void
gtk_minefield_setup_numbers (GtkMineField * mfield)
{
  int minesizepixels, pixel_sz, i;
  static guint last_size = 0;

  minesizepixels = mfield->minesizepixels;

  pixel_sz = minesizepixels - 2;
  if (pixel_sz > 999)
    pixel_sz = 999;

  if (last_size == pixel_sz)
    return;
  last_size = pixel_sz;

  for (i = 0; i < 9; i++) {
    gchar text[2];
    PangoLayout *layout;
    PangoAttrList *alist;
    PangoAttribute *attr;
    PangoFontDescription *font_desc;
    PangoRectangle extent;
    guint64 font_size;

    /* free an existing layout ... */
    if (mfield->numstr[i].layout)
      g_object_unref (mfield->numstr[i].layout);

    text[0] = '0' + i;
    text[1] = '\0';
    layout = gtk_widget_create_pango_layout (GTK_WIDGET (mfield), text);

    /* set attributes for the layout */
    alist = pango_attr_list_new ();

    /* colour */
    attr = pango_attr_foreground_new (num_colors[i][0],
				      num_colors[i][1], num_colors[i][2]);
    attr->start_index = 0;
    attr->end_index = G_MAXUINT;
    pango_attr_list_insert (alist, attr);

    /* do the font */
    font_desc = pango_font_description_new ();
    pango_font_description_set_family (font_desc, "Sans");
    font_size = pixel_sz * PANGO_SCALE * .85;
    pango_font_description_set_absolute_size (font_desc, font_size);
    pango_font_description_set_weight (font_desc, PANGO_WEIGHT_BOLD);
    attr = pango_attr_font_desc_new (font_desc);

    attr->start_index = 0;
    attr->end_index = G_MAXUINT;
    pango_attr_list_insert (alist, attr);

    pango_layout_set_attributes (layout, alist);
    pango_layout_set_alignment (layout, PANGO_ALIGN_CENTER);

    pango_font_description_free (font_desc);
    pango_attr_list_unref (alist);

    mfield->numstr[i].layout = layout;

    pango_layout_get_extents (layout, NULL, &extent);

    /* The +1 is necessary since these coordinates are
     * with respect to minesizepixels, not pixel_sz (the
     * difference is 2). */
    mfield->numstr[i].dx = (pixel_sz - extent.width / PANGO_SCALE) / 2 + 1;
    mfield->numstr[i].dy = (pixel_sz - extent.height / PANGO_SCALE) / 2 + 1;
  }
}

static void
gtk_minefield_realize (GtkWidget * widget)
{
  GtkMineField *mfield;
  GtkAllocation allocation;
  GtkStyle *style;
  GdkWindow *window;
  GdkWindowAttr attributes;
  gint attributes_mask;

  g_return_if_fail (widget != NULL);
  g_return_if_fail (GTK_IS_MINEFIELD (widget));

  mfield = GTK_MINEFIELD (widget);
  gtk_widget_set_realized (widget, TRUE);

  gtk_widget_get_allocation (widget, &allocation);

  attributes.window_type = GDK_WINDOW_CHILD;
  attributes.x = allocation.x;
  attributes.y = allocation.y;
  attributes.width = allocation.width;
  attributes.height = allocation.height;
  attributes.wclass = GDK_INPUT_OUTPUT;
  attributes.visual = gtk_widget_get_visual (widget);
  attributes.event_mask = gtk_widget_get_events (widget);
  attributes.event_mask |= GDK_EXPOSURE_MASK |
    GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK | GDK_POINTER_MOTION_MASK;

  attributes_mask = GDK_WA_X | GDK_WA_Y | GDK_WA_VISUAL;

  window = gdk_window_new (gtk_widget_get_parent_window (widget),
                           &attributes, attributes_mask);
  gtk_widget_set_window (widget, window);
  gdk_window_set_user_data (window, mfield);

  style = gtk_style_attach (gtk_widget_get_style (widget), window);
  gtk_widget_set_style (widget, style);
  gtk_style_set_background (style, window, GTK_STATE_ACTIVE);
}

static void
gtk_minefield_unrealize (GtkWidget * widget)
{
  g_return_if_fail (widget != NULL);
  g_return_if_fail (GTK_IS_MINEFIELD (widget));

  if (GTK_WIDGET_CLASS (parent_class)->unrealize)
    (*GTK_WIDGET_CLASS (parent_class)->unrealize) (widget);
}

/* The frame makes sure that the minefield is allocated the correct size */
/* This is the standard allocate routine - it could be removed and the parents routine inherited */
static void
gtk_minefield_size_allocate (GtkWidget * widget, GtkAllocation * allocation)
{
  guint minesizepixels, width, height;
  guint xofs, yofs;
  GtkMineField *mfield;
  GdkWindow *window;

  gtk_widget_set_allocation (widget, allocation);
  window = gtk_widget_get_window (widget);

  mfield = GTK_MINEFIELD (widget);

  if (gtk_widget_get_realized (widget)) {
    minesizepixels = MIN (allocation->width / mfield->xsize,
		    allocation->height / mfield->ysize);
    mfield->minesizepixels = minesizepixels;
    width = mfield->xsize * minesizepixels;
    height = mfield->ysize * minesizepixels;
    xofs = allocation->x + (allocation->width - width) / 2;
    yofs = allocation->y + (allocation->height - height) / 2;

    gdk_window_move_resize (window, xofs, yofs, width, height);
  }
}

static void
gtk_minefield_get_preferred_width (GtkWidget *widget, gint *minimum, gint *natural)
{
  GtkMineField *mf = GTK_MINEFIELD (widget);

  /* request the minimum size - to allow the widget window to be resized */
  *minimum = *natural = mf->xsize * MINESIZE_MIN;
}

static void
gtk_minefield_get_preferred_height (GtkWidget *widget, gint *minimum, gint *natural)
{
  GtkMineField *mf = GTK_MINEFIELD (widget);

  /* request the minimum size - to allow the widget window to be resized */
  *minimum = *natural = mf->ysize * MINESIZE_MIN;
}

static void
gtk_mine_queue_draw (GtkMineField * mfield, guint x, guint y)
{
  guint minesizepixels = mfield->minesizepixels;

  gtk_widget_queue_draw_area (GTK_WIDGET (mfield),
                              x * minesizepixels, y * minesizepixels,
                              minesizepixels, minesizepixels);
}

static void
gtk_mine_draw (GtkMineField * mfield, cairo_t *cr, guint x, guint y)
{
  int c = get_cell_index (mfield, x, y);
  int noshadow;
  gboolean clicked;
  int n, nm;
  guint minesizepixels;
  GtkStyle *style;
  GtkWidget *widget = GTK_WIDGET (mfield);

  g_return_if_fail (c != -1);

  style = gtk_widget_get_style (widget);

  minesizepixels = mfield->minesizepixels;

  noshadow = mfield->mines[c].shown;

  clicked = mfield->mines[c].down;

  if (noshadow) {		/* draw grid on ocean floor */
    double dots[] = {2, 2};

    gtk_paint_box (style,
		   cr,
		   clicked ? GTK_STATE_ACTIVE : GTK_STATE_NORMAL,
		   GTK_SHADOW_IN,
		   widget,
		   "button", x * minesizepixels, y * minesizepixels, minesizepixels, minesizepixels);
    if (y == 0) {		/* top row only */
      cairo_move_to (cr, x * minesizepixels, 0);
      cairo_line_to (cr, x * minesizepixels + minesizepixels - 1, 0);
    }
    if (x == 0) {		/* left column only */
      cairo_move_to (cr, 0, y * minesizepixels);
      cairo_line_to (cr, 0, y * minesizepixels + minesizepixels - 1);
    }
    cairo_move_to (cr, x * minesizepixels + minesizepixels - 1 + 0.5, y * minesizepixels + 0.5);
    cairo_line_to (cr, x * minesizepixels + minesizepixels - 1 + 0.5, y * minesizepixels + minesizepixels - 1 + 0.5);
    cairo_move_to (cr, x * minesizepixels + 0.5, y * minesizepixels + minesizepixels - 1 + 0.5);
    cairo_line_to (cr, x * minesizepixels + minesizepixels - 1 + 0.5, y * minesizepixels + minesizepixels - 1 + 0.5);

    cairo_save (cr);
    gdk_cairo_set_source_color (cr, &gtk_widget_get_style (widget)->dark[gtk_widget_get_state (widget)]);
    cairo_set_line_width (cr, 1);
    cairo_set_dash (cr, dots, 2, 0);
    cairo_stroke (cr);
    cairo_restore (cr);
  } else {			/* draw shadow around possible mine location */
    gtk_paint_box (style,
		   cr,
		   clicked ? GTK_STATE_ACTIVE : GTK_STATE_SELECTED,
		   clicked ? GTK_SHADOW_IN : GTK_SHADOW_OUT,
		   widget,
		   "button", x * minesizepixels, y * minesizepixels, minesizepixels, minesizepixels);
  }

  if (mfield->mines[c].shown && !mfield->mines[c].mined) {
    n = mfield->mines[c].neighbours;
    g_assert (n >= 0 && n <= 9);

    nm = mfield->mines[c].neighbourmarks;
    g_assert (nm >= 0 && nm <= 9);

    if (mfield->use_overmine_warning && n < nm) {
      gdk_cairo_set_source_pixbuf (cr, mfield->warning.scaledpixbuf,
                                   x * minesizepixels + (minesizepixels - mfield->warning.width) / 2,
                                   y * minesizepixels + (minesizepixels - mfield->warning.height) / 2);
      cairo_rectangle (cr,
                       x * minesizepixels + (minesizepixels - mfield->warning.width) / 2,
                       y * minesizepixels + (minesizepixels - mfield->warning.height) / 2,
                       mfield->warning.width, mfield->warning.height);
      cairo_fill (cr);
    }

    if (n != 0) {
      cairo_move_to (cr,		     
                     x * minesizepixels + mfield->numstr[n].dx,
                     y * minesizepixels + mfield->numstr[n].dy);
      pango_cairo_show_layout (cr, PANGO_LAYOUT (mfield->numstr[n].layout));
    }

  } else if (mfield->mines[c].marked == MINE_QUESTION) {
    gdk_cairo_set_source_pixbuf (cr, mfield->question.scaledpixbuf,
                                 x * minesizepixels + (minesizepixels - mfield->flag.width) / 2,
                                 y * minesizepixels + (minesizepixels - mfield->flag.height) / 2);
    cairo_rectangle (cr,
                     x * minesizepixels + (minesizepixels - mfield->flag.width) / 2,
                     y * minesizepixels + (minesizepixels - mfield->flag.height) / 2,
                     mfield->flag.width, mfield->flag.height);
    cairo_fill (cr);
  } else if (mfield->mines[c].marked == MINE_MARKED) {
    gdk_cairo_set_source_pixbuf (cr, mfield->flag.scaledpixbuf,
                                 x * minesizepixels + (minesizepixels - mfield->flag.width) / 2,
                                 y * minesizepixels + (minesizepixels - mfield->flag.height) / 2);
    cairo_rectangle (cr,
                     x * minesizepixels + (minesizepixels - mfield->flag.width) / 2,
                     y * minesizepixels + (minesizepixels - mfield->flag.height) / 2,
                     mfield->flag.width, mfield->flag.height);
    cairo_fill (cr);

    if (mfield->lose && mfield->mines[c].mined != 1) {
      int x1 = x * minesizepixels + 0.1 * minesizepixels;
      int y1 = y * minesizepixels + 0.1 * minesizepixels;
      int x2 = x * minesizepixels + 0.9 * minesizepixels;
      int y2 = y * minesizepixels + 0.9 * minesizepixels;

      cairo_move_to (cr, x1, y1);
      cairo_line_to (cr, x2, y2);
      cairo_move_to (cr, x1, y2);
      cairo_line_to (cr, x2, y1);

      cairo_save (cr);
      gdk_cairo_set_source_color (cr, &gtk_widget_get_style (widget)->black);
      cairo_set_line_width (cr, MAX (1, 0.1 * minesizepixels));
      cairo_set_line_join (cr, CAIRO_LINE_JOIN_ROUND);
      cairo_set_line_cap (cr, CAIRO_LINE_CAP_ROUND);
      cairo_stroke (cr);
      cairo_restore (cr);
    }
  } else if (mfield->lose && mfield->mines[c].mined) {
    gdk_cairo_set_source_pixbuf (cr, mfield->mine.scaledpixbuf,
                                 x * minesizepixels + (minesizepixels - mfield->flag.width) / 2,
                                 y * minesizepixels + (minesizepixels - mfield->flag.height) / 2);
    cairo_rectangle (cr,
                     x * minesizepixels + (minesizepixels - mfield->flag.width) / 2,
                     y * minesizepixels + (minesizepixels - mfield->flag.height) / 2,
                     mfield->flag.width, mfield->flag.height);
    cairo_fill (cr);
  }
  if (mfield->lose && mfield->mines[c].mined && mfield->mines[c].shown) {
    gdk_cairo_set_source_pixbuf (cr, mfield->bang.scaledpixbuf,
                                 x * minesizepixels + (minesizepixels - mfield->bang.width) / 2,
                                 y * minesizepixels + (minesizepixels - mfield->bang.height) / 2);
    cairo_rectangle (cr,
                     x * minesizepixels + (minesizepixels - mfield->bang.width) / 2,
                     y * minesizepixels + (minesizepixels - mfield->bang.height) / 2,
                     mfield->bang.width, mfield->bang.height);
    cairo_fill (cr);
  }
}

static gboolean
gtk_minefield_draw (GtkWidget * widget, cairo_t * cr)
{
  g_return_val_if_fail (widget != NULL, FALSE);
  g_return_val_if_fail (GTK_IS_MINEFIELD (widget), FALSE);

  if (gtk_widget_is_drawable (widget)) {
    guint x, y;
    GtkMineField *mfield = GTK_MINEFIELD (widget);

    /* mine square numbers must be resized to fit the mine size */
    gtk_minefield_setup_signs (mfield);
    gtk_minefield_setup_numbers (mfield);

    for (x = 0; x < mfield->xsize; x++)
      for (y = 0; y < mfield->ysize; y++)
	gtk_mine_draw (mfield, cr, x, y);
  }
  return FALSE;
}

static int
gtk_minefield_check_cell (GtkMineField * mfield, guint x, guint y)
{
  guint changed;
  gint c;
  guint i;
  gint nx, ny;

  changed = 0;

  for (i = 0; i < 8; i++) {
    nx = x + neighbour_map[i].x;
    ny = y + neighbour_map[i].y;
    if ((c = get_cell_index (mfield, nx, ny)) != -1) {
      if (mfield->mines[c].shown == 0 &&
	  mfield->mines[c].marked == MINE_NOMARK) {
	mfield->mines[c].shown = 1;
	mfield->shown++;
	gtk_mine_queue_draw (mfield, nx, ny);
	changed = 1;
      }
    }
  }
  return changed;
}


static void
gtk_minefield_check_field (GtkMineField * mfield, gint x, gint y)
{
  gint c;
  guint changed;

  gint x1, y1, x2, y2;
  gint cx1, cx2, cy1, cy2;

  cx1 = cx2 = x;
  cy1 = cy2 = y;

  do {
    x1 = cx1 - 1;
    y1 = cy1 - 1;
    x2 = cx2 + 1;
    y2 = cy2 + 1;

    if (x1 < 0)
      x1 = 0;
    if (y1 < 0)
      y1 = 0;
    if (x2 >= mfield->xsize)
      x2 = mfield->xsize - 1;
    if (y2 >= mfield->ysize)
      y2 = mfield->ysize - 1;

    changed = 0;
    for (x = x1; x <= x2; x++) {
      for (y = y1; y <= y2; y++) {
	c = get_cell_index_no_checks (mfield, x, y);
	if (mfield->mines[c].neighbours == 0 && mfield->mines[c].shown == 1) {
	  changed |= gtk_minefield_check_cell (mfield, x, y);
	  if (changed) {
	    if (x < cx1)
	      cx1 = x;
	    if (x > cx2)
	      cx2 = x;
	    if (y < cy1)
	      cy1 = y;
	    if (y > cy2)
	      cy2 = y;
	  }
	}
      }
    }
  } while (changed);

  if (mfield->shown == mfield->xsize * mfield->ysize - mfield->mcount) {
    gtk_minefield_win (mfield);
  }
}

static void
gtk_minefield_lose (GtkMineField * mfield)
{
  guint i, x, y;

  g_signal_emit (G_OBJECT (mfield),
		 minefield_signals[EXPLODE_SIGNAL], 0, NULL);

  mfield->lose = 1;

  /* draw mines and wrong markings */
  for (i = 0; i <mfield->xsize * mfield->ysize; i++) {
    if (mfield->mines[i].mined || mfield->mines[i].marked) {
      y = i / mfield->xsize;
      x = i % mfield->xsize;
      gtk_mine_queue_draw (mfield, x, y);
    }
  }
}

static void
gtk_minefield_win (GtkMineField * mfield)
{
  guint x, y, c;

  /* mark any unmarked mines and update displayed total */
  for (x = 0; x < mfield->xsize; x++) {
    for (y = 0; y < mfield->ysize; y++) {
      c = x + y * mfield->xsize;
      if (mfield->mines[c].shown == 0 &&	/* not shown & not marked */
	  mfield->mines[c].marked != MINE_MARKED) {

	mfield->mines[c].marked = MINE_MARKED;	/* mark it */
	gtk_mine_queue_draw (mfield, x, y);	/* draw it */
	mfield->flag_count++;	/* up the count */
	g_signal_emit (G_OBJECT (mfield),	/* display the count */
		       minefield_signals[MARKS_CHANGED_SIGNAL], 0, NULL);
      }
    }
  }


  mfield->win = 1;

  /* now stop the clock.  (MARKS_CHANGED_SIGNAL starts it) */
  /* Make sure this is the last thing called so it is safe to
   * start a new game in the win_signal handler. */
  g_signal_emit (G_OBJECT (mfield), minefield_signals[WIN_SIGNAL], 0, NULL);
}

static void
gtk_minefield_randomize (GtkMineField * mfield, int curloc)
{
  guint i, j;
  guint x, y;
  guint n;
  gint cidx;
  gboolean adj_found;

  /* randomly set the mines, but avoid the current and adjacent locations */

  x = curloc % mfield->xsize;
  y = curloc / mfield->xsize;

  for (n = 0; n < mfield->mcount;) {
    i = g_rand_int_range (mfield->grand, 0, mfield->xsize * mfield->ysize);

    if (!mfield->mines[i].mined && i != curloc) {
      adj_found = FALSE;

      for (j = 0; j < 8; j++)
	adj_found |=
	  (i ==
	   get_cell_index (mfield, x + neighbour_map[j].x, y + neighbour_map[j].y));

      if (!adj_found) {
	mfield->mines[i].mined = 1;
	n++;
      }
    }
  }

  /* load neighborhood numbers */
  for (x = 0; x < mfield->xsize; x++) {
    for (y = 0; y < mfield->ysize; y++) {
      n = 0;
      for (i = 0; i < 8; i++) {
	if (((cidx = get_cell_index (mfield, x + neighbour_map[i].x,
			       y + neighbour_map[i].y)) != -1) &&
	    mfield->mines[cidx].mined) {
	  n++;
	}
      }
      mfield->mines[x + mfield->xsize * y].neighbours = n;

      n = 0;
      for (i = 0; i < 8; i++) {
	if (((cidx = get_cell_index (mfield, x + neighbour_map[i].x,
			       y + neighbour_map[i].y)) != -1) &&
	    mfield->mines[cidx].marked == MINE_MARKED) {
	  n++;
	}
      }
      mfield->mines[x + mfield->xsize * y].neighbourmarks = n;
    }
  }
}

static void
gtk_minefield_show (GtkMineField * mfield, guint x, guint y)
{
  int c = get_cell_index (mfield, x, y);

  g_return_if_fail (c != -1);

  /* make sure first click isn't on a mine */
  if (!mfield->in_play) {
    mfield->in_play = 1;
    gtk_minefield_randomize (mfield, c);
  }

  if (mfield->mines[c].marked != MINE_MARKED && mfield->mines[c].shown != 1) {
    mfield->mines[c].shown = 1;
    mfield->shown++;
    gtk_mine_queue_draw (mfield, x, y);
    if (mfield->mines[c].mined == 1) {
      gtk_minefield_lose (mfield);
    } else {
      gtk_minefield_check_field (mfield, x, y);
    }
  }
}

static void
gtk_minefield_set_mark (GtkMineField * mfield, guint x, guint y, int mark)
{
  int c = get_cell_index (mfield, x, y);
  int change_count, i, nx, ny, c2;
  gboolean was_valid, is_valid;
   
  g_return_if_fail (c != -1);

  /* Cannot mark if square already revealed */
  if (mfield->mines[c].shown != 0)
    return;

  /* Don't change if already has this mark */
  if (mfield->mines[c].marked == mark)
    return;
   
  /* Decide if we are adding or removing a mark */
  if (mark == MINE_MARKED) {
    change_count = 1;
  } else {
    if (mfield->mines[c].marked == MINE_MARKED)
      change_count = -1;
    else
      change_count = 0;
  }
   
  /* If mark count changed update counters in adjacent squares */
  if (change_count != 0)
  {
    mfield->flag_count += change_count;
    for (i = 0; i < 8; i++) {
      nx = x + neighbour_map[i].x;
      ny = y + neighbour_map[i].y;
      if ((c2 = get_cell_index (mfield, nx, ny)) == -1)
	continue;
       
      was_valid = mfield->mines[c2].neighbourmarks <= mfield->mines[c2].neighbours;
      mfield->mines[c2].neighbourmarks += change_count;
      is_valid = mfield->mines[c2].neighbourmarks <= mfield->mines[c2].neighbours;

      /* Redraw if too many marks placed */
      if (is_valid != was_valid)
	gtk_mine_queue_draw (mfield, nx, ny);
    }
  }

  /* Update marking */
  mfield->mines[c].marked = mark;
  gtk_mine_queue_draw (mfield, x, y);
  g_signal_emit (G_OBJECT (mfield),
		 minefield_signals[MARKS_CHANGED_SIGNAL], 0, NULL);
}
    
static void
gtk_minefield_toggle_mark (GtkMineField * mfield, guint x, guint y)
{
  int mark = MINE_NOMARK, c = get_cell_index (mfield, x, y);

  switch (mfield->mines[c].marked) {
  case MINE_NOMARK:
    /* If we've used all the flags don't plant any more,
     * this should be an indication to the player that they
     * have made a mistake. */
    if (mfield->flag_count == mfield->mcount && mfield->use_question_marks)
      mark = MINE_QUESTION;
    else
      mark = MINE_MARKED;
    break;

  case MINE_MARKED:
    if (mfield->use_question_marks)
      mark = MINE_QUESTION;
    break;
  }

  gtk_minefield_set_mark (mfield, x, y, mark);
}

static void
gtk_minefield_multi_press (GtkMineField * mfield, guint x, guint y, gint c)
{
  guint i;
  gint nx, ny, c2;

  for (i = 0; i < 8; i++) {
    nx = x + neighbour_map[i].x;
    ny = y + neighbour_map[i].y;
    if ((c2 = get_cell_index (mfield, nx, ny)) == -1)
      continue;
    if (mfield->mines[c2].marked != MINE_MARKED && !mfield->mines[c2].shown) {
      mfield->mines[c2].down = 1;
      gtk_mine_queue_draw (mfield, nx, ny);
    }
  }
  mfield->multi_mode = 1;
}

static gboolean
gtk_minefield_solve_square (GtkMineField * mfield, guint x, guint y, guint c)
{
   gint nc, i, nx, ny, empty_count = 0, unknown[8][2], set_count = 0;

   /* Look for unmarked neighbour squares */
   for(i = 0; i < 8; i++) {
      nx = x + neighbour_map[i].x;
      ny = y + neighbour_map[i].y;
      nc = get_cell_index (mfield, nx, ny);
      if(nc < 0)
	continue;
      if(!mfield->mines[nc].shown) {
	 if(mfield->mines[nc].marked != MINE_MARKED) {
	    unknown[set_count][0] = nx;
	    unknown[set_count][1] = ny;
	    set_count++;
	 }
	 empty_count++;
      }
   }

   if(mfield->mines[c].neighbours != empty_count || set_count == 0)
     return FALSE;

   for(i = 0; i < set_count; i++)
     gtk_minefield_set_mark (mfield, unknown[i][0], unknown[i][1], MINE_MARKED);
   
   return TRUE;
}

static void
gtk_minefield_multi_release (GtkMineField * mfield, guint x, guint y, guint c,
			     guint really)
{
  gint nx, ny, i, c2;
  guint lose = 0;

  if (c >= mfield->xsize * mfield->ysize) /* The release was outside the main area. */
    return;

  mfield->multi_mode = 0;

  if (mfield->mines[c].neighbours != mfield->mines[c].neighbourmarks ||
      mfield->mines[c].marked == MINE_MARKED || !mfield->mines[c].shown)
    really = 0;

  for (i = 0; i < 8; i++) {
    nx = x + neighbour_map[i].x;
    ny = y + neighbour_map[i].y;
    if ((c2 = get_cell_index (mfield, nx, ny)) == -1)
      continue;
    if (mfield->mines[c2].down) {
      mfield->mines[c2].down = 0;
      if (really && (mfield->mines[c2].shown == 0)) {
	mfield->mines[c2].shown = 1;
	mfield->shown++;
	if (mfield->mines[c2].mined == 1) {
	  lose = 1;
	}
      }
      gtk_mine_queue_draw (mfield, nx, ny);
    }
  }
  if (lose) {
    gtk_minefield_lose (mfield);
  } else if (really) {
    gtk_minefield_check_field (mfield, x, y);
  }
}

static gint
gtk_minefield_motion_notify (GtkWidget * widget, GdkEventMotion * event)
{
  GtkMineField *mfield;
  guint x, y;
  gint c;
  guint minesizepixels;

  g_return_val_if_fail (widget != NULL, 0);
  g_return_val_if_fail (GTK_IS_MINEFIELD (widget), 0);
  g_return_val_if_fail (event != NULL, 0);

  mfield = GTK_MINEFIELD (widget);

  minesizepixels = mfield->minesizepixels;

  if (mfield->lose || mfield->win)
    return FALSE;

  x = event->x / minesizepixels;
  y = event->y / minesizepixels;

  c = get_cell_index (mfield, x, y);
  if (c == -1)
    return 0;

  /* If mouse pointer over a cell that wasn't first pressed => dragging.*/
  if (c != mfield->celldown) {
    /* If left or middle mouse button down. */
    if (mfield->buttondown[0] || mfield->buttondown[1]) {
      mfield->mines[mfield->celldown].down = 0;
      gtk_mine_queue_draw (mfield, mfield->celldownx, mfield->celldowny);

      if (mfield->multi_mode)
	gtk_minefield_multi_release (mfield, mfield->celldownx,
				     mfield->celldowny, mfield->celldown, 0);
      mfield->celldownx = x;
      mfield->celldowny = y;
      mfield->celldown = c;
      mfield->mines[c].down = 1;
      gtk_mine_queue_draw (mfield, x, y);

      /* Clear action is active and the current cell is shown. */
      if (mfield->action == CLEAR_ACTION && mfield->mines[c].shown)
        gtk_minefield_multi_press (mfield, x, y, c);
    } else if (mfield->buttondown[2]) {
      /*  Update clicked field on right click drag.*/
      mfield->mines[mfield->celldown].down = 0;
      mfield->action = NO_ACTION;
      gtk_mine_queue_draw (mfield, mfield->celldownx, mfield->celldowny);

      mfield->celldownx = x;
      mfield->celldowny = y;
      mfield->celldown = c;
      mfield->mines[c].down = 1;
    }
  }
  return FALSE;
}

static gint
gtk_minefield_button_press (GtkWidget * widget, GdkEventButton * event)
{
  GtkMineField *mfield;
  guint x, y;
  gint c;
  guint minesizepixels;

  g_return_val_if_fail (widget != NULL, 0);
  g_return_val_if_fail (GTK_IS_MINEFIELD (widget), 0);
  g_return_val_if_fail (event != NULL, 0);

  mfield = GTK_MINEFIELD (widget);

  minesizepixels = mfield->minesizepixels;

  if (mfield->lose || mfield->win)
    return FALSE;

  /* Left or right mouse button has been clicked. */
  if (event->button <= 3 && !mfield->buttondown[1]) {
    /* Translate mouse coordinates to minefield coordinates
     * and do some sanity checking. */
    x = event->x / minesizepixels;
    y = event->y / minesizepixels;
    c = get_cell_index (mfield, x, y);
    if (c == -1)
      return FALSE;
      
    /* If this is the first button pressed (on a cell),
     * record where it was pressed. */
    if (!mfield->buttondown[0] && !mfield->buttondown[1]) {
      mfield->celldownx = x;
      mfield->celldowny = y;
      mfield->celldown = c;
      mfield->mines[c].down = 1;
    }
    mfield->buttondown[event->button - 1]++;

    /* Redraw the cell, which is now being pressed. */
    gtk_mine_queue_draw (mfield, x, y);

    /* Determine what action to do. Normally this is
     * left button = show, middle = clear and right = flag.
     * Unfortunately we have to detect left+right because
     * MS Minesweeper did this and some people will be used to
     * it. As well as that left + shift is also clear for people
     * with two button mice and less dexterity. In addition
     * we also want left = clear when that is the only 
     * reasonable action (i.e. we click on a cleared square)
     * since this makes it even easier for two-button mice,
     * but we didn't think of it soon enough not to have to worry 
     * about all the extra legacy crap. */
    switch (event->button) {
    case 1: /* Left click. */
      mfield->action = SHOW_ACTION;
      if ((event->state & GDK_SHIFT_MASK) || (mfield->buttondown[2]) || (mfield->mines[c].shown))
        mfield->action = CLEAR_ACTION;
      /* Ctrl + left = right to make game playable on touchpad */
      if (event->state & GDK_CONTROL_MASK)
        mfield->action = FLAG_ACTION;
      break;
    case 2: /* Middle click. */
      mfield->action = CLEAR_ACTION;
      break;
    case 3: /* Right click. */
      mfield->action = FLAG_ACTION;
      if (mfield->buttondown[0])
        mfield->action = CLEAR_ACTION;
      break;
    }

    /* Now actually do the actions. Most of the real work
     * is done in the button_release handler. */
    if (mfield->action == CLEAR_ACTION) {
      gtk_minefield_multi_press (mfield, x, y, c);
    } else if (mfield->action == FLAG_ACTION) {
      if (mfield->buttondown[2] == 1 || (event->state & GDK_CONTROL_MASK && mfield->buttondown[0] == 1)) {
        gtk_minefield_toggle_mark (mfield, x, y);
      }
    }
    if (mfield->action != FLAG_ACTION) {
      g_signal_emit (G_OBJECT (mfield),
		     minefield_signals[LOOK_SIGNAL], 0, NULL);
    }
  }
  return FALSE;
}

static gint
gtk_minefield_button_release (GtkWidget * widget, GdkEventButton * event)
{
  GtkMineField *mfield;
  gboolean really;

  g_return_val_if_fail (widget != NULL, FALSE);
  g_return_val_if_fail (GTK_IS_MINEFIELD (widget), FALSE);
  g_return_val_if_fail (event != NULL, FALSE);

  mfield = GTK_MINEFIELD (widget);

  if (mfield->lose || mfield->win)
    return FALSE;

  /* If mouse button released and gtk_minefield_button_press caught it too. */
  if (event->button <= 3 && mfield->buttondown[event->button - 1]) {
    switch (mfield->action) {
    case SHOW_ACTION:
      gtk_minefield_show (mfield, mfield->celldownx, mfield->celldowny);
      break;
    case CLEAR_ACTION:
       if (mfield->use_autoflag)
         really = ! gtk_minefield_solve_square (mfield, mfield->celldownx,
                        mfield->celldowny, mfield->celldown);
       else
	     really = TRUE;
       gtk_minefield_multi_release (mfield, mfield->celldownx, mfield->celldowny,
				      mfield->celldown, really);
       break;
    }
    if (!mfield->lose && !mfield->win) {
      g_signal_emit (G_OBJECT (mfield),
		     minefield_signals[UNLOOK_SIGNAL], 0, NULL);
    }
    mfield->mines[mfield->celldown].down = 0;
    mfield->action = NO_ACTION;
    mfield->buttondown[event->button - 1] = 0;
    gtk_mine_queue_draw (mfield, mfield->celldownx, mfield->celldowny);
  }
  return FALSE;
}


static void
gtk_minefield_class_init (GtkMineFieldClass * class)
{
  GtkWidgetClass *widget_class = GTK_WIDGET_CLASS (class);
  GObjectClass *object_class = G_OBJECT_CLASS (class);

  parent_class = g_type_class_peek_parent (class);

  widget_class->realize = gtk_minefield_realize;
  widget_class->unrealize = gtk_minefield_unrealize;
  widget_class->size_allocate = gtk_minefield_size_allocate;
  widget_class->get_preferred_width = gtk_minefield_get_preferred_width;
  widget_class->get_preferred_height = gtk_minefield_get_preferred_height;
  widget_class->draw = gtk_minefield_draw;
  widget_class->button_press_event = gtk_minefield_button_press;
  widget_class->button_release_event = gtk_minefield_button_release;
  widget_class->motion_notify_event = gtk_minefield_motion_notify;

  class->marks_changed = NULL;
  class->explode = NULL;
  class->look = NULL;
  class->unlook = NULL;
  class->win = NULL;

  minefield_signals[MARKS_CHANGED_SIGNAL] =
    g_signal_new ("marks_changed",
		  G_OBJECT_CLASS_TYPE (object_class),
		  G_SIGNAL_RUN_FIRST,
		  G_STRUCT_OFFSET (GtkMineFieldClass, marks_changed),
		  NULL, NULL, g_cclosure_marshal_VOID__VOID, G_TYPE_NONE, 0);

  minefield_signals[EXPLODE_SIGNAL] =
    g_signal_new ("explode",
		  G_OBJECT_CLASS_TYPE (object_class),
		  G_SIGNAL_RUN_FIRST,
		  G_STRUCT_OFFSET (GtkMineFieldClass, explode),
		  NULL, NULL, g_cclosure_marshal_VOID__VOID, G_TYPE_NONE, 0);
  minefield_signals[LOOK_SIGNAL] =
    g_signal_new ("look",
		  G_OBJECT_CLASS_TYPE (object_class),
		  G_SIGNAL_RUN_FIRST,
		  G_STRUCT_OFFSET (GtkMineFieldClass, look),
		  NULL, NULL, g_cclosure_marshal_VOID__VOID, G_TYPE_NONE, 0);
  minefield_signals[UNLOOK_SIGNAL] =
    g_signal_new ("unlook",
		  G_OBJECT_CLASS_TYPE (object_class),
		  G_SIGNAL_RUN_FIRST,
		  G_STRUCT_OFFSET (GtkMineFieldClass, unlook),
		  NULL, NULL, g_cclosure_marshal_VOID__VOID, G_TYPE_NONE, 0);
  minefield_signals[WIN_SIGNAL] =
    g_signal_new ("win",
		  G_OBJECT_CLASS_TYPE (object_class),
		  G_SIGNAL_RUN_FIRST,
		  G_STRUCT_OFFSET (GtkMineFieldClass, win),
		  NULL, NULL, g_cclosure_marshal_VOID__VOID, G_TYPE_NONE, 0);
  minefield_signals[HINT_SIGNAL] =
    g_signal_new ("hint-used",
		  G_OBJECT_CLASS_TYPE (object_class),
		  G_SIGNAL_RUN_FIRST,
		  G_STRUCT_OFFSET (GtkMineFieldClass, hint_used),
		  NULL, NULL, g_cclosure_marshal_VOID__VOID, G_TYPE_NONE, 0);

}

static void
gtk_minefield_init (GtkMineField * mfield)
{
  mfield->xsize = 0;
  mfield->ysize = 0;
  mfield->mines = NULL;
  mfield->started = FALSE;
  mfield->celldown = -1;
  mfield->action = NO_ACTION;

  mfield->flag.preimage = NULL;
  mfield->mine.preimage = NULL;
  mfield->question.preimage = NULL;
  mfield->bang.preimage = NULL;
  mfield->warning.preimage = NULL;
  mfield->grand = g_rand_new ();
}

void
gtk_minefield_set_size (GtkMineField * mfield, guint xsize, guint ysize)
{
  g_return_if_fail (mfield != NULL);
  g_return_if_fail (GTK_IS_MINEFIELD (mfield));

  if ((mfield->xsize == xsize) && (mfield->ysize == ysize))
    return;

  mfield->mines = g_realloc (mfield->mines, sizeof (mine) * xsize * ysize);

  mfield->xsize = xsize;
  mfield->ysize = ysize;

  if (gtk_widget_get_visible (GTK_WIDGET (mfield))) {
    gtk_widget_queue_resize (GTK_WIDGET (mfield));
  }
}

GtkWidget *
gtk_minefield_new (void)
{
  return GTK_WIDGET (g_object_new (GTK_TYPE_MINEFIELD, NULL));
}

GType
gtk_minefield_get_type (void)
{
  static GType minefield_type = 0;

  if (minefield_type == 0) {
    static const GTypeInfo minefield_info = {
      sizeof (GtkMineFieldClass),
      NULL,			/* base_init */
      NULL,			/* base_finalize */
      (GClassInitFunc) gtk_minefield_class_init,
      NULL,			/* class_finalize */
      NULL,			/* class_data */
      sizeof (GtkMineField),
      0,			/* n_preallocs */
      (GInstanceInitFunc) gtk_minefield_init,
      NULL,			/* value table */
    };

    minefield_type = g_type_register_static (GTK_TYPE_WIDGET,
					     "GtkMineField",
					     &minefield_info, 0);
  }

  return minefield_type;
}

void
gtk_minefield_restart (GtkMineField * mfield)
{
  guint i;

  g_return_if_fail (mfield != NULL);
  g_return_if_fail (GTK_IS_MINEFIELD (mfield));

  mfield->flag_count = 0;
  mfield->shown = 0;
  mfield->lose = 0;
  mfield->win = 0;
  mfield->buttondown[0] = 0;
  mfield->buttondown[1] = 0;
  mfield->buttondown[2] = 0;
  mfield->celldown = -1;
  mfield->multi_mode = 0;
  mfield->in_play = 0;

  for (i = 0; i < mfield->xsize * mfield->ysize; i++) {
    mfield->mines[i].marked = MINE_NOMARK;
    mfield->mines[i].mined = 0;
    mfield->mines[i].shown = 0;
    mfield->mines[i].down = 0;
  }

  if (mfield->started == FALSE)
    mfield->started = TRUE;
  else
    gtk_widget_queue_draw (GTK_WIDGET (mfield));
}

void
gtk_minefield_set_use_question_marks (GtkMineField * mfield,
				      gboolean use_question_marks)
{
  g_return_if_fail (mfield != NULL);
  g_return_if_fail (GTK_IS_MINEFIELD (mfield));

  mfield->use_question_marks = use_question_marks;
}

void
gtk_minefield_set_use_overmine_warning (GtkMineField * mfield,
					gboolean use_overmine_warning)
{
  g_return_if_fail (mfield != NULL);
  g_return_if_fail (GTK_IS_MINEFIELD (mfield));

  mfield->use_overmine_warning = use_overmine_warning;

  gtk_widget_queue_draw (GTK_WIDGET (mfield));
}

void
gtk_minefield_set_use_autoflag (GtkMineField * mfield,
				gboolean use_autoflag)
{
  g_return_if_fail (mfield != NULL);
  g_return_if_fail (GTK_IS_MINEFIELD (mfield));

  mfield->use_autoflag = use_autoflag;

  gtk_widget_queue_draw (GTK_WIDGET (mfield));
}

/* Hunt for a hint to give the player. Revealed squares are handled here,
 * everything else is passed back up. The comments below detail the
 * strategy for revealing squares. */
gint
gtk_minefield_hint (GtkMineField * mfield)
{
  gint i, x, y;
  gint a, c;
  mine *m;
  guint ncase1, ncase2, ncase3;
  guint *case1list, *case2list, *case3list;
  guint *case1ptr, *case2ptr, *case3ptr;
  gint size;
  gint retval;

  g_return_val_if_fail (mfield != NULL, MINEFIELD_HINT_NO_GAME);
  g_return_val_if_fail (GTK_IS_MINEFIELD (mfield), MINEFIELD_HINT_NO_GAME);
  if (!mfield->in_play)
    return MINEFIELD_HINT_NO_GAME;

  /* We search for three cases:
   *
   * Case 1: we look for squares adjacent to both a mine and a revealed
   * square since these are most likely to help the player and resolve
   * ambiguous situations.
   *
   * Case 2: we look for squares that are adjacent to a mine
   * (this will only occur in the rare case that a square is completely
   * encircled by mines, but at that point this case is probably
   * useful).
   *
   * Case 3: we look for any unrevealed square without a mine (as a
   * consequence of the previous cases this won't be adjacent to a
   * mine).
   */

  /* This code is pretty diabolical,
   * Yet it is perfectly logical,
   * Is it C ?
   * Is it me ?
   * Or is it just pathological ?
   */

  size = mfield->xsize * mfield->ysize;
  case1ptr = case1list = g_malloc (size * sizeof (guint));
  case2ptr = case2list = g_malloc (size * sizeof (guint));
  case3ptr = case3list = g_malloc (size * sizeof (guint));
  ncase1 = ncase2 = ncase3 = 0;

  for (i = 0; i < size; i++) {
    m = mfield->mines + i;
    if (!m->mined && !m->marked && !m->shown) {
      ncase3++;
      *case3ptr++ = i;
      if (m->neighbours > 0) {
	ncase2++;
	*case2ptr++ = i;
	x = i % mfield->xsize;
	y = i / mfield->ysize;
	for (a = 0; a < 8; a++) {
	  c = get_cell_index (mfield,
			x + neighbour_map[a].x, y + neighbour_map[a].y);
	  if ((c != -1) && mfield->mines[c].shown) {
	    ncase1++;
	    *case1ptr++ = i;
	    break;
	  }
	}
      }
    }
  }

  if (ncase1 > 0) {
    a = g_rand_int_range (mfield->grand, 0, ncase1);
    i = case1list[a];
  } else if (ncase2 > 0) {
    a = g_rand_int_range (mfield->grand, 0, ncase2);
    i = case2list[a];
  } else if (ncase3 > 0) {
    a = g_rand_int_range (mfield->grand, 0, ncase3);
    i = case3list[a];
  } else {
    retval = MINEFIELD_HINT_ALL_MINES;
    goto cleanup;
  }

  x = i % mfield->xsize;
  y = i / mfield->xsize;

  /* Makes sure that the program knows about the successful
   * hint before a possible win. */
  g_signal_emit (G_OBJECT (mfield),
		 minefield_signals[HINT_SIGNAL], 0, NULL);
  gtk_minefield_show (mfield, x, y);
  gtk_mine_queue_draw (mfield, x, y);
  retval = MINEFIELD_HINT_ACCEPTED;

cleanup:
  g_free (case1list);
  g_free (case2list);
  g_free (case3list);

  return retval;
}
