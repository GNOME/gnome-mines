
#include <time.h>
#include <gtk/gtk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gnome.h>
#include "minefield.h"

static struct {
	gint x;
	gint y;
} neighbour_map[8] = {
	{ -1,  1 },
	{ 0 ,  1 },
	{ 1 ,  1 },
	{ 1 ,  0 },
	{ 1 , -1 },
	{ 0 , -1 },
	{ -1, -1 },
	{ -1, 0  }
};



static guint16 num_colors[9][3] = {
	{ 0x0000, 0x0000, 0x0000 }, /* Black, not used */
	{ 0x0000, 0x0000, 0xffff }, /* Blue  */
	{ 0x0000, 0xa0a0, 0x0000 }, /* Green */
	{ 0xffff, 0x0000, 0x0000 }, /* Red   */
	{ 0x0000, 0x0000, 0x7fff }, /* DarkBlue */
	{ 0xa0a0, 0x0000, 0x0000 }, /* DarkRed   */
	{ 0x0000, 0xffff, 0xffff }, /* Cyan */
	{ 0xa0a0, 0x0000, 0xa0a0 }, /* DarkViolet */
	{ 0x0000, 0x0000, 0x0000 }  /* Black */
};


time_t secs = 0;

enum {
	MARKS_CHANGED_SIGNAL,
	EXPLODE_SIGNAL,
	LOOK_SIGNAL,
	UNLOOK_SIGNAL,
	WIN_SIGNAL,
	LAST_SIGNAL
};

static gint minefield_signals[LAST_SIGNAL] = { 0 };
static GtkWidgetClass *parent_class;

/*  Prototypes */
static inline gint cell_idx(GtkMineField *mfield, guint x, guint y);
static void gtk_mine_draw(GtkMineField *mfield, guint x, guint y);
static gint gtk_minefield_button_press(GtkWidget *widget, GdkEventButton *event);
static gint gtk_minefield_button_release(GtkWidget *widget, GdkEventButton *event);
static void gtk_minefield_check_field(GtkMineField *mfield, gint x, gint y);
static void gtk_minefield_class_init (GtkMineFieldClass *class);
static gint gtk_minefield_expose(GtkWidget *widget, GdkEventExpose *event);
static void gtk_minefield_init (GtkMineField *mfield);
static void gtk_minefield_lose(GtkMineField *mfield);
static gint gtk_minefield_motion_notify(GtkWidget *widget, GdkEventMotion *event);
static void gtk_minefield_multi_release (GtkMineField *mfield, guint x, guint y, guint c, guint really);
static void gtk_minefield_randomize(GtkMineField *mfield, int curloc);
static void gtk_minefield_realize(GtkWidget *widget);
static void gtk_minefield_setup_signs(GtkWidget *widget);
static void gtk_minefield_show(GtkMineField *mfield, guint x, guint y);
static void gtk_minefield_size_allocate(GtkWidget *widget, GtkAllocation *allocation);
static void gtk_minefield_size_request(GtkWidget *widget, GtkRequisition *requisition);
static void gtk_minefield_toggle_mark(GtkMineField *mfield, guint x, guint y);
static void gtk_minefield_unrealize (GtkWidget *widget);
static void gtk_minefield_win(GtkMineField *mfield);
static inline int gtk_minefield_check_cell(GtkMineField *mfield, guint x, guint y);
static void _setup_sign (sign *signp, const char *file, guint minesize);
static inline void gtk_minefield_multi_press(GtkMineField *mfield, guint x, guint y, gint c);
/* end prototypes */



static inline gint cell_idx(GtkMineField *mfield, guint x, guint y)
{
	if (x>=0 && x<mfield->xsize && y>=0 && y<mfield->ysize)
		return x+y*mfield->xsize;
	return -1;
}

static void _setup_sign (sign *signp, const char *file, guint minesize)
{
        /* minesize parameter is not used */
	GdkPixbuf *image;
	/* TODO: catch GError */
	image = gdk_pixbuf_new_from_file (file, NULL);

	gdk_pixbuf_render_pixmap_and_mask (image, &signp->pixmap,
					   &signp->mask, 127);

	g_object_unref (image);
	gdk_drawable_get_size(signp->pixmap, &(signp->width), &(signp->height));
}

static void gtk_minefield_setup_signs(GtkWidget *widget)
{
        GtkMineField *mfield;
  
        mfield = GTK_MINEFIELD(widget);
  
        _setup_sign(&mfield->flag, DATADIR"/pixmaps/gnomine/flag.png", mfield->minesize);
        _setup_sign(&mfield->mine, DATADIR"/pixmaps/gnomine/mine.png", mfield->minesize);
        _setup_sign(&mfield->question, DATADIR"/pixmaps/gnomine/flag-question.png", mfield->minesize);
}

static void
gtk_minefield_setup_numbers(GtkMineField *mfield)
{
	int minesize, pixel_sz, i;
	  
	minesize = mfield->minesize;

	pixel_sz = minesize - 2;
	if (pixel_sz > 999) pixel_sz = 999;
	if (pixel_sz < 2)  pixel_sz = 2;
  
	for (i=0; i<9; i++) {
		gchar text[2];
		PangoLayout *layout;
		PangoAttrList *alist;
		PangoAttribute *attr;
		PangoFontDescription *font_desc;

		/* free an existing layout ... */
		if (mfield->numstr[i].layout)
			g_object_unref(mfield->numstr[i].layout);

		text[0] = '0' + i;
		text[1] = '\0';
		layout = gtk_widget_create_pango_layout(GTK_WIDGET(mfield),
							text);

		/* set attributes for the layout */
		alist = pango_attr_list_new();

		/* do the font */
		font_desc = pango_font_description_new();
		pango_font_description_set_family(font_desc, "Mono 8");
		pango_font_description_set_size(font_desc,
						pixel_sz * PANGO_SCALE * 0.7);
		pango_font_description_set_weight(font_desc,PANGO_WEIGHT_BOLD);
		attr = pango_attr_font_desc_new(font_desc);
		pango_font_description_free(font_desc);

		attr->start_index = 0;
		attr->end_index = G_MAXUINT;
		pango_attr_list_insert(alist, attr);

		/* colour */
		attr = pango_attr_foreground_new(num_colors[i][0],
						 num_colors[i][1],
						 num_colors[i][2]);
		attr->start_index = 0;
		attr->end_index = G_MAXUINT;
		pango_attr_list_insert(alist, attr);

		pango_layout_set_attributes(layout, alist);
		pango_attr_list_unref(alist);

		pango_layout_set_width(layout, minesize);
		pango_layout_set_alignment(layout, PANGO_ALIGN_CENTER);

		mfield->numstr[i].layout = layout;

		mfield->numstr[i].dx = minesize / 2;
		/* Hack to fix the number being too far down */
		mfield->numstr[i].dy = (minesize - pixel_sz) / 2 - 4;
	}
}

static void gtk_minefield_realize(GtkWidget *widget)
{
        GtkMineField *mfield;
        GdkWindowAttr attributes;
        gint attributes_mask;
        
        g_return_if_fail(widget != NULL);
        g_return_if_fail(GTK_IS_MINEFIELD (widget));
        
        mfield = GTK_MINEFIELD(widget);
        GTK_WIDGET_SET_FLAGS(widget, GTK_REALIZED);
        
        attributes.window_type = GDK_WINDOW_CHILD;
        attributes.x = widget->allocation.x;
        attributes.y = widget->allocation.y;
        attributes.width = widget->allocation.width;
        attributes.height = widget->allocation.height;
        attributes.wclass = GDK_INPUT_OUTPUT;
        attributes.visual = gtk_widget_get_visual(widget);
        attributes.colormap = gtk_widget_get_colormap(widget);
        attributes.event_mask = gtk_widget_get_events(widget);
	attributes.event_mask |= GDK_EXPOSURE_MASK |
	                         GDK_BUTTON_PRESS_MASK |
		                 GDK_BUTTON_RELEASE_MASK |
                                 GDK_POINTER_MOTION_MASK;
        
        attributes_mask = GDK_WA_X | GDK_WA_Y | GDK_WA_VISUAL | GDK_WA_COLORMAP;
        
	widget->window = gdk_window_new(widget->parent->window,
	                                &attributes, attributes_mask);
        gdk_window_set_user_data(widget->window, mfield);
        
        widget->style = gtk_style_attach(widget->style, widget->window);
        gtk_style_set_background(widget->style, widget->window, GTK_STATE_ACTIVE);

        gtk_minefield_setup_signs(widget);
}

static void gtk_minefield_unrealize (GtkWidget *widget)
{
	g_return_if_fail (widget != NULL);
	g_return_if_fail (GTK_IS_MINEFIELD (widget));

	if (GTK_WIDGET_CLASS (parent_class)->unrealize)
		(* GTK_WIDGET_CLASS (parent_class)->unrealize) (widget);
}

static void gtk_minefield_size_allocate(GtkWidget *widget,
					GtkAllocation *allocation)
{
        g_return_if_fail(widget != NULL);
        g_return_if_fail(GTK_IS_MINEFIELD (widget));
        g_return_if_fail(allocation != NULL);

        widget->allocation = *allocation;
        
	if (GTK_WIDGET_REALIZED(widget)) {
		gdk_window_move_resize(widget->window,
				       allocation->x, allocation->y,
				       GTK_MINEFIELD(widget)->xsize *
				       GTK_MINEFIELD(widget)->minesize,
				       GTK_MINEFIELD(widget)->ysize *
				       GTK_MINEFIELD(widget)->minesize);
	}
}

static void gtk_minefield_size_request(GtkWidget *widget,
				       GtkRequisition *requisition)
{
        requisition->width  = GTK_MINEFIELD(widget)->xsize *
		              GTK_MINEFIELD(widget)->minesize;

	requisition->height = GTK_MINEFIELD(widget)->ysize * 
		              GTK_MINEFIELD(widget)->minesize;
}

static void gtk_mine_draw(GtkMineField *mfield, guint x, guint y)
{
        int c = cell_idx(mfield, x, y);
	int noshadow;
	int n;
	guint minesize;
        static GdkGC *dots;
        static char stipple_data[]  = { 0x03, 0x03, 0x0c, 0x0c };
        static GdkPixmap *stipple = NULL;
        GtkWidget *widget = GTK_WIDGET(mfield);

        /* This gives us a dotted line to increase the contrast between
         * buttons and the "sea". */
        if (stipple == NULL) {
          stipple = gdk_bitmap_create_from_data (NULL, stipple_data, 4, 4);
          dots = gdk_gc_new (widget->window);
          gdk_gc_copy (dots, widget->style->dark_gc[2]);
          gdk_gc_set_stipple (dots, stipple);
          g_object_unref (stipple);
          gdk_gc_set_fill (dots, GDK_STIPPLED);
        }
                
	minesize = mfield->minesize;

	if (mfield->lose || mfield->win) {
		noshadow = mfield->mines[c].shown;
	} else {
		noshadow = mfield->mines[c].down || mfield->mines[c].shown;
	}
	
	gdk_window_clear_area(widget->window, x * minesize, y * minesize,
	                      minesize, minesize);

	if (noshadow) { /* draw grid on ocean floor */
		if (y == 0) {	/* top row only */
			gdk_draw_line(widget->window,	/* top */
			              dots,
	                              x*minesize,
	                              0,
	                              x*minesize+minesize-1,
	                              0);
		}
		if (x == 0) {	/* left column only */
			gdk_draw_line(widget->window,	/* left */
			              dots,
	                              0,
	                              y*minesize,
	                              0,
	                              y*minesize+minesize-1);
		}
		gdk_draw_line(widget->window,	/* right */
                              dots,
                              x*minesize+minesize-1,
                              y*minesize,
                              x*minesize+minesize-1,
                              y*minesize+minesize-1);
		gdk_draw_line(widget->window,	/* bottom */
		              dots,
                              x*minesize,
                              y*minesize+minesize-1,
                              x*minesize+minesize-1,
                              y*minesize+minesize-1);

	} else {	/* draw shadow around possible mine location */
		gtk_paint_shadow(widget->style, widget->window,
		                GTK_WIDGET_STATE (widget), GTK_SHADOW_OUT,
				NULL, widget, NULL,
		                x*minesize, y*minesize, minesize, minesize);
        }

	if (mfield->mines[c].shown && !mfield->mines[c].mined) {
		if ((n = mfield->mines[c].neighbours) != 0) {
			g_assert (n >= 0 && n <= 9);
			gdk_draw_layout(widget->window,
					widget->style->black_gc,
					x*minesize + mfield->numstr[n].dx,
					y*minesize + mfield->numstr[n].dy+1,
					PANGO_LAYOUT(mfield->numstr[n].layout));
		}

	} else if (mfield->mines[c].marked == MINE_QUESTION) {
		gdk_gc_set_clip_mask(widget->style->black_gc,
		                     mfield->question.mask);
		gdk_gc_set_clip_origin(widget->style->black_gc,
		                       x * minesize + (minesize - mfield->question.width) / 2, 
		                       y * minesize + (minesize - mfield->question.height) / 2);
		gdk_draw_drawable (widget->window,
		                 widget->style->black_gc,
		                 mfield->question.pixmap, 0, 0,
		                 x * minesize + (minesize - mfield->question.width) / 2, 
		                 y * minesize + (minesize - mfield->question.height) / 2,
		                 -1, -1);
		gdk_gc_set_clip_mask(widget->style->black_gc, NULL);
	  
	} else if (mfield->mines[c].marked == MINE_MARKED) {
		gdk_gc_set_clip_mask(widget->style->black_gc,
					     mfield->flag.mask);
		gdk_gc_set_clip_origin(widget->style->black_gc,
					       x * minesize + (minesize - mfield->flag.width) / 2, 
					       y * minesize + (minesize - mfield->flag.height) / 2);
		gdk_draw_drawable (widget->window,
				 widget->style->black_gc,
		                 mfield->flag.pixmap, 0, 0,
		                 x * minesize + (minesize - mfield->flag.width) / 2, 
		                 y * minesize + (minesize - mfield->flag.height) / 2,
		                 -1, -1);
	        gdk_gc_set_clip_mask(widget->style->black_gc, NULL);
	  
		if (mfield->lose && mfield->mines[c].mined != 1) {
			gdk_draw_line(widget->window,
				      widget->style->black_gc,
				      x*minesize+2,
				      y*minesize+3,
				      x*minesize+minesize-4,
				      y*minesize+minesize-3);
			gdk_draw_line(widget->window,
				      widget->style->black_gc,
				      x*minesize+3,
				      y*minesize+2,
				      x*minesize+minesize-3,
				      y*minesize+minesize-4);
			gdk_draw_line(widget->window,
				      widget->style->black_gc,
				      x*minesize+2,
				      y*minesize+minesize-4,
				      x*minesize+minesize-4,
				      y*minesize+2);
			gdk_draw_line(widget->window,
				      widget->style->black_gc,
				      x*minesize+3,
				      y*minesize+minesize-3,
				      x*minesize+minesize-3,
				      y*minesize+3);
		}

	} else if (mfield->lose && mfield->mines[c].mined) {
		if (mfield->mine.mask) {
			gdk_gc_set_clip_mask(widget->style->black_gc,
					     mfield->mine.mask);
			gdk_gc_set_clip_origin(widget->style->black_gc,
					       x*minesize + (minesize - mfield->mine.width) / 2, 
					       y*minesize + (minesize - mfield->mine.height) / 2);
		}

	        gdk_draw_drawable (widget->window,
				 widget->style->black_gc,
		                 mfield->mine.pixmap, 0, 0,
		                 x * minesize + (minesize - mfield->mine.width) / 2,
		                 y * minesize + (minesize - mfield->mine.height) / 2,
		                 -1, -1);
		
		if (mfield->flag.mask) {
			gdk_gc_set_clip_mask(widget->style->black_gc, NULL);
		}
	}
}

static gint gtk_minefield_expose (GtkWidget      *widget,
				  GdkEventExpose *event)
{
	g_return_val_if_fail (widget != NULL, FALSE);
        g_return_val_if_fail (GTK_IS_MINEFIELD (widget), FALSE);
        g_return_val_if_fail (event != NULL, FALSE);

	if (GTK_WIDGET_DRAWABLE (widget)) {
		guint x1, y1, x2, y2, x, y;
		GtkMineField *mfield = GTK_MINEFIELD (widget);
		GdkRectangle *area = &event->area;

		if (area) {
			x1 = area->x/mfield->minesize;
			y1 = area->y/mfield->minesize;
			x2 = (area->x + area->width - 1) / mfield->minesize;
			y2 = (area->y + area->height - 1) / mfield->minesize;
		} else {
			x1 = 0; y1 = 0;
			x2 = mfield->xsize - 1;
			y2 = mfield->ysize - 1;
		}

		/* These are necessary because we get an expose call before a
		 * resize at the old size, but after we have changed our data. */
		if (x2 >= mfield->xsize)
			x2 = mfield->xsize - 1;
		if (y2 >= mfield->ysize)
			y2 = mfield->ysize - 1;
		
		for (x = x1; x <= x2; x++)
			for (y = y1; y <= y2; y++)
				gtk_mine_draw (mfield, x, y);
	}
	return FALSE;
}

static inline int gtk_minefield_check_cell(GtkMineField *mfield, guint x, guint y)
{
        guint changed;
        gint c;
        guint i;
        gint nx, ny;

        changed = 0;
        
        for (i=0; i<8; i++) {
                nx = x+neighbour_map[i].x;
                ny = y+neighbour_map[i].y;
                if ((c = cell_idx(mfield, nx, ny)) != -1) {
                        if (mfield->mines[c].shown == 0 &&
			    mfield->mines[c].marked == MINE_NOMARK) {
				mfield->mines[c].shown = 1;
                                mfield->shown++;
				gtk_mine_draw(mfield, nx, ny);
				changed = 1;
			}
                }
        }
        return changed;
}


static void gtk_minefield_check_field(GtkMineField *mfield, gint x, gint y)
{
        guint c;
        guint changed;

        gint x1, y1, x2, y2;
        gint cx1, cx2, cy1, cy2;

        cx1 = cx2 = x;
        cy1 = cy2 = y;
        
        do {
		x1 = cx1-1;
		y1 = cy1-1;
		x2 = cx2+1;
		y2 = cy2+1;

		if (x1 < 0) x1 = 0;
		if (y1 < 0) y1 = 0;
		if (x2 >= mfield->xsize) x2 = mfield->xsize-1;
		if (y2 >= mfield->ysize) y2 = mfield->ysize-1;
		
		changed = 0;
                for (x=x1; x<=x2; x++) {
                        for (y=y1; y<=y2; y++) {
                                c = cell_idx(mfield, x, y);
                                if (mfield->mines[c].neighbours == 0 &&
                                    mfield->mines[c].shown == 1) {
					changed |= gtk_minefield_check_cell(mfield, x, y);
					if (changed) {
						if (x < cx1) cx1 = x;
						if (x > cx2) cx2 = x;
						if (y < cy1) cy1 = y;
						if (y > cy2) cy2 = y;
					}
                                }
                        }
                }
        } while (changed);
}

static void gtk_minefield_lose (GtkMineField *mfield)
{
        g_signal_emit (G_OBJECT (mfield),
                        minefield_signals[EXPLODE_SIGNAL],
			0, NULL );
        mfield->lose = 1;
	gtk_widget_queue_draw (GTK_WIDGET (mfield));
}

static void gtk_minefield_win(GtkMineField *mfield)
{
        guint x, y, c;

	/* mark any unmarked mines and update displayed total */
	for (x = 0; x < mfield->xsize; x++) {
		for (y = 0; y < mfield->ysize; y++) {
			c = x + y * mfield->xsize;
			if (mfield->mines[c].shown == 0 && /* not shown & not marked */
			    mfield->mines[c].marked != MINE_MARKED) {

				mfield->mines[c].marked = MINE_MARKED; /* mark it */
				gtk_mine_draw(mfield, x, y);           /* draw it */
				mfield->flag_count++;                  /* up the count */
				g_signal_emit(GTK_OBJECT(mfield),    /* display the count */
						minefield_signals[MARKS_CHANGED_SIGNAL],
						0, NULL);
			}
                        }
                }

	/* now stop the clock.  (MARKS_CHANGED_SIGNAL starts it) */
        g_signal_emit(GTK_OBJECT(mfield),
                        minefield_signals[WIN_SIGNAL],
			0, NULL);

        mfield->win = 1;
}

static void gtk_minefield_randomize (GtkMineField *mfield, int curloc)
{
	guint i;
	guint x, y;
	guint n;
	guint cidx;
	static GRand *grand = NULL;

	if (grand == NULL)
		grand = g_rand_new ();

	/* randomly set the mines, but avoid the current location (why ?)*/
	for (n = 0; n < mfield->mcount; ) {
	        i = g_rand_int_range (grand, 0, mfield->xsize * mfield->ysize);
		if (!mfield->mines[i].mined && i != curloc) {
		        mfield->mines[i].mined = 1;
			n++;
		}
	}

	/* load neighborhood numbers */
	for (x=0; x<mfield->xsize; x++) {
		for (y=0; y<mfield->ysize; y++) {
			n = 0;
			for (i=0; i<8; i++) {
				if (((cidx = cell_idx(mfield, x + neighbour_map[i].x,
				                      y+neighbour_map[i].y)) != -1) &&
					mfield->mines[cidx].mined) {
					n++;
				}
			}
			mfield->mines[x+mfield->xsize * y].neighbours = n;
		}
	}
}

static void gtk_minefield_show(GtkMineField *mfield, guint x, guint y)
{
	int c = x + mfield->xsize * y;

	/* make sure first click isn't on a mine */
	if (!mfield->in_play) {
		mfield->in_play = 1;
		gtk_minefield_randomize(mfield, c);
	}
	
	if (mfield->mines[c].marked != MINE_MARKED &&
	    mfield->mines[c].shown != 1) {
		mfield->mines[c].shown = 1;
		mfield->shown++;
                gtk_mine_draw(mfield, mfield->cdownx, mfield->cdowny);
                if(mfield->mines[c].mined == 1) {
			gtk_minefield_lose(mfield);
                } else {
			gtk_minefield_check_field(mfield, x, y);
			if (mfield->shown == mfield->xsize*mfield->ysize-mfield->mcount) {
                                gtk_minefield_win(mfield);
			}
		}
        }
}

static void gtk_minefield_toggle_mark(GtkMineField *mfield, guint x, guint y)
{
        int c = cell_idx(mfield, x, y);

	if (mfield->mines[c].shown != 0) { /* nothing to toggle */
		return;
	}

	switch (mfield->mines[c].marked) {
	case MINE_NOMARK:
		mfield->mines[c].marked = MINE_MARKED;
		mfield->flag_count++;
		break;
	case MINE_MARKED:
		if (mfield->use_question_marks) {
			mfield->mines[c].marked = MINE_QUESTION;
		} else {
			mfield->mines[c].marked = MINE_NOMARK;
		}
		mfield->flag_count--;
		break;
	case MINE_QUESTION:
		mfield->mines[c].marked = MINE_NOMARK;
		break;
	default:
		/* better not get here! */
		break;
		}

		g_signal_emit(GTK_OBJECT(mfield),
				minefield_signals[MARKS_CHANGED_SIGNAL],
				0, NULL);
	if (mfield->shown == mfield->xsize * mfield->ysize-mfield->mcount) {
                        gtk_minefield_win(mfield);
		}
}

static inline void gtk_minefield_multi_press(GtkMineField *mfield,
                                             guint x, guint y, gint c)
{
        guint i;
        gint nx, ny, c2;

        for (i=0; i<8; i++) {
                nx = x+neighbour_map[i].x;
                ny = y+neighbour_map[i].y;
                if ((c2 = cell_idx(mfield, nx, ny)) == -1)
                        continue;
		if (mfield->mines[c2].marked != MINE_MARKED &&
		    !mfield->mines[c2].shown) {
                        mfield->mines[c2].down = 1;
                        gtk_mine_draw(mfield, nx, ny);
                }
        }
        mfield->multi_mode = 1;
}

static void gtk_minefield_multi_release (GtkMineField *mfield, guint x, guint y, guint c, guint really)
{
        gint n, nx, ny, i, c2;
	guint lose = 0;

        mfield->multi_mode = 0;

        n = 0;
        for (i=0; i<8; i++) {
                nx = x+neighbour_map[i].x;
                ny = y+neighbour_map[i].y;
                if ((c2 = cell_idx(mfield, nx, ny)) == -1)
                        continue;
		if (mfield->mines[c2].marked == MINE_MARKED)
			n++;
        }
        if (mfield->mines[c].neighbours != n ||
	    mfield->mines[c].marked == MINE_MARKED ||
	    !mfield->mines[c].shown)
			really = 0;

        for (i=0; i<8; i++) {
                nx = x+neighbour_map[i].x;
                ny = y+neighbour_map[i].y;
                if ((c2 = cell_idx(mfield, nx, ny)) == -1)
                        continue;
                if (mfield->mines[c2].down) {
                        mfield->mines[c2].down = 0;
                        if (really) {
				mfield->mines[c2].shown = 1;
				mfield->shown++;
                                if (mfield->mines[c2].mined == 1) {
					lose = 1;
                                }
                        }
                        gtk_mine_draw(mfield, nx ,ny);
                }
        }
	if (lose) {
		gtk_minefield_lose(mfield);
        } else if (really) {
                gtk_minefield_check_field(mfield, x, y);
                if (mfield->shown == mfield->xsize*mfield->ysize-mfield->mcount) {
			gtk_minefield_win(mfield);
		}
        }
}

static gint gtk_minefield_motion_notify(GtkWidget *widget, GdkEventMotion *event)
{
        GtkMineField *mfield;
	guint x, y;
        guint c;
        guint multi;
	guint minesize;
	
        g_return_val_if_fail(widget != NULL, 0);
        g_return_val_if_fail(GTK_IS_MINEFIELD(widget), 0);
        g_return_val_if_fail(event != NULL, 0);

        mfield = GTK_MINEFIELD(widget);

	minesize = mfield->minesize;

        if (mfield->lose || mfield->win) return FALSE;

        if (mfield->bdown[0] || mfield->bdown[1]) {
                x = event->x/minesize;
                y = event->y/minesize;

                if (x < 0 || y < 0 || x > mfield->xsize-1 || y > mfield->ysize-1)
                        return 0;

                c = x+y*(mfield->xsize);

                if (c != mfield->cdown) {
                        mfield->mines[mfield->cdown].down = 0;
                        gtk_mine_draw(mfield, mfield->cdownx, mfield->cdowny);

                        multi = mfield->multi_mode;
			if (multi)
				gtk_minefield_multi_release(mfield, mfield->cdownx,
				                            mfield->cdowny,
				                            mfield->cdown, 0);
                        mfield->cdownx = x;
                        mfield->cdowny = y;
                        mfield->cdown = c;
                        mfield->mines[c].down = 1;
                        gtk_mine_draw(mfield, x, y);

			if (multi)
				gtk_minefield_multi_press(mfield, x, y, c);
                }
        }
        return FALSE;
}

static gint gtk_minefield_button_press(GtkWidget *widget, GdkEventButton *event)
{
        GtkMineField *mfield;
	guint x, y;
	guint c;
	guint minesize;
        
        g_return_val_if_fail(widget != NULL, 0);
        g_return_val_if_fail(GTK_IS_MINEFIELD(widget), 0);
        g_return_val_if_fail(event != NULL, 0);

        mfield = GTK_MINEFIELD(widget);

	minesize = mfield->minesize;

	if (mfield->lose || mfield->win) return FALSE;
	
        if (event->button <= 3 && !mfield->bdown[1]) {
                x = event->x/minesize;
                y = event->y/minesize;
                c = x+y*(mfield->xsize);
                if (!mfield->bdown[0] && !mfield->bdown[1] && !mfield->bdown[2]) {
                        mfield->cdownx = x;
                        mfield->cdowny = y;
                        mfield->cdown = c;
                        mfield->mines[c].down = 1;
                }
		mfield->bdown[event->button-1]++;
                gtk_mine_draw(mfield, x, y);
                if (((event->button == 2) || (event->button == 1 && event->state & GDK_SHIFT_MASK)) ||
		   (mfield->bdown[0] && mfield->bdown[2]) ) { /* multi show */
                        gtk_minefield_multi_press(mfield, x, y, c);
                }
                else if (event->button == 3 && mfield->bdown[2] == 1)
                {
                        gtk_minefield_toggle_mark(mfield, x, y);
                        gtk_mine_draw(mfield, x, y);
                }
		if (event->button == 1 || event->button == 2) {
			g_signal_emit(GTK_OBJECT(mfield),
					minefield_signals[LOOK_SIGNAL],
					0, NULL);
		}
        }
        return FALSE;
}

static gint gtk_minefield_button_release(GtkWidget *widget, GdkEventButton *event)
{
        GtkMineField *mfield;

        g_return_val_if_fail(widget != NULL, FALSE);
        g_return_val_if_fail(GTK_IS_MINEFIELD(widget), FALSE);
        g_return_val_if_fail(event != NULL, FALSE);

	mfield = GTK_MINEFIELD(widget);

	if (mfield->lose || mfield->win) return FALSE;

        if (event->button <= 3 && mfield->bdown[event->button-1]) {
                if (mfield->bdown[0] && mfield->bdown[2] && event->button != 2) {
                    /* left+right click = multi show */
                    mfield->bdown[0] = 0;
                    mfield->bdown[1] = 1;
                    mfield->bdown[2] = 0;
                    event->button = 2;
                }
                switch (event->button) {
                case 1:
			if (event->state & GDK_SHIFT_MASK) gtk_minefield_multi_release(mfield, mfield->cdownx, mfield->cdowny, mfield->cdown, 1);
			else gtk_minefield_show(mfield, mfield->cdownx, mfield->cdowny);
                        break;
                case 2: if (mfield->multi_mode) gtk_minefield_multi_release(mfield, mfield->cdownx, mfield->cdowny, mfield->cdown, 1);
                        break;
                }
		if (!mfield->lose && !mfield->win) {
			g_signal_emit(GTK_OBJECT(mfield),
					minefield_signals[UNLOOK_SIGNAL],
					0, NULL);
		}
		mfield->mines[mfield->cdown].down = 0;
                mfield->cdown = -1;
		mfield->bdown[event->button-1] = 0;
		gtk_mine_draw(mfield, mfield->cdownx, mfield->cdowny);
        }
        return FALSE;
}


static void gtk_minefield_class_init (GtkMineFieldClass *class)
{
 	GtkWidgetClass *widget_class = GTK_WIDGET_CLASS (class);
 	GtkObjectClass *object_class = GTK_OBJECT_CLASS (class);

	parent_class = gtk_type_class (gtk_widget_get_type ());
	
        widget_class->realize = gtk_minefield_realize;
	widget_class->unrealize = gtk_minefield_unrealize;
        widget_class->size_allocate = gtk_minefield_size_allocate;
        widget_class->size_request = gtk_minefield_size_request;
        widget_class->expose_event = gtk_minefield_expose;
        widget_class->button_press_event = gtk_minefield_button_press;
	widget_class->button_release_event = gtk_minefield_button_release;
	widget_class->motion_notify_event = gtk_minefield_motion_notify;

        class->marks_changed = NULL;
        class->explode = NULL;
        class->look = NULL;
        class->unlook = NULL;
        class->win = NULL;
  
	minefield_signals[MARKS_CHANGED_SIGNAL] =
		g_signal_new("marks_changed",
				G_OBJECT_CLASS_TYPE (object_class),
			       G_SIGNAL_RUN_FIRST,
			       G_STRUCT_OFFSET(GtkMineFieldClass, marks_changed),
			       NULL, NULL,
			       g_cclosure_marshal_VOID__VOID,
			       G_TYPE_NONE,
			       0);

	minefield_signals[EXPLODE_SIGNAL] =
		g_signal_new("explode",
				G_OBJECT_CLASS_TYPE (object_class),
			       G_SIGNAL_RUN_FIRST,
			       G_STRUCT_OFFSET(GtkMineFieldClass, explode),
			       NULL, NULL,
			       g_cclosure_marshal_VOID__VOID,
			       G_TYPE_NONE,
			       0);
	minefield_signals[LOOK_SIGNAL] =
		g_signal_new("look",
				G_OBJECT_CLASS_TYPE (object_class),
			       G_SIGNAL_RUN_FIRST,
			       G_STRUCT_OFFSET(GtkMineFieldClass, look),
			       NULL, NULL,
			       g_cclosure_marshal_VOID__VOID,
			       G_TYPE_NONE,
			       0);
	minefield_signals[UNLOOK_SIGNAL] =
		g_signal_new("unlook",
				G_OBJECT_CLASS_TYPE (object_class),
			       G_SIGNAL_RUN_FIRST,
			       G_STRUCT_OFFSET(GtkMineFieldClass, unlook),
			       NULL, NULL,
			       g_cclosure_marshal_VOID__VOID,
			       G_TYPE_NONE,
			       0);
	minefield_signals[WIN_SIGNAL] =
		g_signal_new("win",
				G_OBJECT_CLASS_TYPE (object_class),
			       G_SIGNAL_RUN_FIRST,
			       G_STRUCT_OFFSET(GtkMineFieldClass, win),
			       NULL, NULL,
			       g_cclosure_marshal_VOID__VOID,
			       G_TYPE_NONE,
			       0);
}

static void gtk_minefield_init (GtkMineField *mfield)
{
        mfield->xsize = 0;
        mfield->ysize = 0;
	mfield->mines = NULL;
	mfield->started = FALSE;
	mfield->cdown = -1;

        GTK_WIDGET (mfield)->requisition.width = mfield->minesize;
        GTK_WIDGET (mfield)->requisition.height = mfield->minesize;

	gtk_minefield_setup_signs(GTK_WIDGET(mfield));
	gtk_minefield_setup_numbers(mfield);
}

void gtk_minefield_set_size(GtkMineField *mfield, guint xsize, guint ysize)
{
        g_return_if_fail(mfield != NULL);
        g_return_if_fail(GTK_IS_MINEFIELD(mfield));

	if (mfield->xsize*mfield->ysize != xsize*ysize) {
		mfield->mines = g_realloc(mfield->mines,
					  sizeof(mine)*xsize*ysize);
	}

	if (mfield->xsize != xsize || mfield->ysize != ysize) {
		mfield->xsize = xsize;
		mfield->ysize = ysize;
		if (GTK_WIDGET_VISIBLE(mfield)) {
			gtk_widget_queue_resize(GTK_WIDGET(mfield)); 
		}
	}
}

GtkWidget* gtk_minefield_new (void)
{
	return GTK_WIDGET (g_object_new (GTK_TYPE_MINEFIELD, NULL));
}

GType gtk_minefield_get_type (void)
{
        static GType minefield_type = 0;
        
	if (minefield_type == 0) {
                static const GTypeInfo minefield_info =
                        {
                                sizeof (GtkMineFieldClass),
				NULL, /* base_init */
				NULL, /* base_finalize */
                                (GClassInitFunc) gtk_minefield_class_init,
				NULL, /* class_finalize */
				NULL, /* class_data */
				sizeof (GtkMineField),
				0, /* n_preallocs */
                                (GInstanceInitFunc) gtk_minefield_init,
                        };
                        
                        minefield_type = g_type_register_static (GTK_TYPE_WIDGET,
					"GtkMineField",
					&minefield_info,
					0);
        }
        
        return minefield_type;
}

void gtk_minefield_set_mines(GtkMineField *mfield, guint mcount, guint minesize)
{
        g_return_if_fail(mfield != NULL);
        g_return_if_fail(GTK_IS_MINEFIELD(mfield));
	g_return_if_fail(minesize>0);
	
        mfield->mcount = mcount;

	if (mfield->minesize != minesize) {
		mfield->minesize = minesize;
		gtk_minefield_setup_numbers(mfield);
		if (GTK_WIDGET_VISIBLE(mfield)) {
                  gtk_widget_queue_resize(GTK_WIDGET(mfield));
		}
	}
}

void gtk_minefield_restart (GtkMineField *mfield)
{
	guint i;

        g_return_if_fail (mfield != NULL);
        g_return_if_fail (GTK_IS_MINEFIELD (mfield));

	mfield->flag_count = 0;
	mfield->shown = 0;
	mfield->lose  = 0;
	mfield->win   = 0;
	mfield->bdown[0] = 0;
	mfield->bdown[1] = 0;
	mfield->bdown[2] = 0;
        mfield->cdown = -1;
        mfield->multi_mode = 0;
	mfield->in_play = 0;

	for (i=0; i < mfield->xsize * mfield->ysize; i++) {
		mfield->mines[i].marked = MINE_NOMARK;
		mfield->mines[i].mined  = 0;
                mfield->mines[i].shown  = 0;
		mfield->mines[i].down   = 0;
	}

        if (mfield->started == FALSE)
		mfield->started = TRUE;
	else
                gtk_widget_queue_draw (GTK_WIDGET (mfield));
}

void gtk_minefield_set_use_question_marks(GtkMineField *mfield, gboolean use_question_marks)
{
	g_return_if_fail(mfield != NULL);
	g_return_if_fail(GTK_IS_MINEFIELD(mfield));
	
	mfield->use_question_marks = use_question_marks;
}
