
#include <time.h>
#include <gtk/gtk.h>
#include <gnome.h>
#include "minefield.h"

#define MINESIZE 17

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



static int num_colors[9][3] = {
	{ 0  , 0  , 0   }, /* Black, not used */
	{ 0  , 0  , 255 }, /* Blue  */
	{ 0  , 160, 0   }, /* Green */
	{ 255, 0  , 0   }, /* Red   */
	{ 255, 0  , 255 }, /* Violet */
	{ 0  , 0  , 127 }, /* DarkBlue */
	{ 0  , 127, 0   }, /* DarkGreen */
	{ 160, 0  , 0   }, /* DarkRed   */
	{ 160, 0  , 160 }  /* DarkViolet */
};


int secs = 0;

static gint minefield_signals[LAST_SIGNAL] = { 0 };

static inline gint cell_idx(GtkMineField *mfield, guint x, guint y)
{
	if (x>=0 && x<mfield->xsize && y>=0 && y<mfield->ysize)
		return x+y*mfield->xsize;
	return -1;
}

static void gtk_minefield_realize(GtkWidget *widget)
{
        GtkMineField *mfield;
        GdkWindowAttr attributes;
        gint attributes_mask;
	char *marked_filename;
	char *mine_filename;
        
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
	attributes.event_mask |= GDK_EXPOSURE_MASK | GDK_BUTTON_PRESS_MASK |
		GDK_BUTTON_RELEASE_MASK;
        
        attributes_mask = GDK_WA_X | GDK_WA_Y | GDK_WA_VISUAL | GDK_WA_COLORMAP;
        
        widget->window = gdk_window_new(widget->parent->window, &attributes, attributes_mask);
        gdk_window_set_user_data(widget->window, mfield);
        
        widget->style = gtk_style_attach(widget->style, widget->window);
        gtk_style_set_background(widget->style, widget->window, GTK_STATE_ACTIVE);

	marked_filename = gnome_unconditional_pixmap_file(MARKED_SIGN_FILENAME);
	mine_filename = gnome_unconditional_pixmap_file(MINE_SIGN_FILENAME);

	gnome_create_pixmap_gdk(widget->window,
				&mfield->marked_sign,
				&mfield->marked_sign_mask,
				&widget->style->bg[GTK_STATE_NORMAL],
				marked_filename);

	gnome_create_pixmap_gdk(widget->window,
				&mfield->mine_sign,
				&mfield->mine_sign_mask,
				&widget->style->bg[GTK_STATE_NORMAL],
				mine_filename);

	g_free(marked_filename);
	g_free(mine_filename);
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
				       GTK_MINEFIELD(widget)->xsize*MINESIZE,
				       GTK_MINEFIELD(widget)->ysize*MINESIZE);
	}
}

static void gtk_minefield_size_request(GtkWidget *widget,
				       GtkRequisition *requisition)
{
        requisition->width  = GTK_MINEFIELD(widget)->xsize*MINESIZE;
	requisition->height = GTK_MINEFIELD(widget)->ysize*MINESIZE;
}

static void gtk_mine_draw(GtkMineField *mfield, guint x, guint y)
{
        int c = cell_idx(mfield, x, y);
	int shadow_type;
	int n;
        GtkWidget *widget = GTK_WIDGET(mfield);

	if (mfield->lose || mfield->win) {
		shadow_type = mfield->mines[c].shown ? GTK_SHADOW_IN : GTK_SHADOW_OUT;
	} else {
		shadow_type = mfield->mines[c].down || mfield->mines[c].shown ?
			GTK_SHADOW_IN : GTK_SHADOW_OUT;
	}
	
	gdk_window_clear_area(widget->window,
			      x*MINESIZE, y*MINESIZE,
			      MINESIZE,
			      MINESIZE);

	gtk_draw_shadow(widget->style, widget->window,
			GTK_WIDGET_STATE (widget), shadow_type,
			x*MINESIZE, y*MINESIZE,
			MINESIZE,
			MINESIZE);

	if (mfield->mines[c].shown && !mfield->mines[c].mined) {
		if ((n = mfield->mines[c].neighbours) != 0) {
			gdk_draw_string(widget->window,
					mfield->font,
					mfield->numstr[n].gc,
					x*MINESIZE+mfield->numstr[n].dx,
					y*MINESIZE+mfield->numstr[n].dy,
					mfield->numstr[n].text);
		}
	} else if (mfield->mines[c].marked == 1) {
		gdk_draw_pixmap (widget->window,
				 widget->style->black_gc,
				 mfield->marked_sign,
				 0, 0, x*MINESIZE+3, y*MINESIZE+3, -1, -1);
		if (mfield->lose && mfield->mines[c].mined != 1) {
			gdk_draw_line(widget->window,
				      widget->style->black_gc,
				      x*MINESIZE+2,
				      y*MINESIZE+3,
				      x*MINESIZE+MINESIZE-4,
				      y*MINESIZE+MINESIZE-3);
			gdk_draw_line(widget->window,
				      widget->style->black_gc,
				      x*MINESIZE+3,
				      y*MINESIZE+2,
				      x*MINESIZE+MINESIZE-3,
				      y*MINESIZE+MINESIZE-4);
			gdk_draw_line(widget->window,
				      widget->style->black_gc,
				      x*MINESIZE+2,
				      y*MINESIZE+MINESIZE-4,
				      x*MINESIZE+MINESIZE-4,
				      y*MINESIZE+2);
			gdk_draw_line(widget->window,
				      widget->style->black_gc,
				      x*MINESIZE+3,
				      y*MINESIZE+MINESIZE-3,
				      x*MINESIZE+MINESIZE-3,
				      y*MINESIZE+3);
		}
	} else if ( mfield->lose && mfield->mines[c].mined) {
		if (mfield->mine_sign_mask) {
			gdk_gc_set_clip_mask(widget->style->black_gc,
					     mfield->mine_sign_mask);
			gdk_gc_set_clip_origin(widget->style->black_gc,
					       x*MINESIZE+3, y*MINESIZE+3);
		}
		
		gdk_draw_pixmap (widget->window,
				 widget->style->black_gc,
				 mfield->mine_sign,
				 0, 0, x*MINESIZE+3, y*MINESIZE+3, -1, -1);
		
		if (mfield->marked_sign_mask) {
			gdk_gc_set_clip_mask(widget->style->black_gc, NULL);
		}
	}
}

void gtk_minefield_draw(GtkMineField *mfield, GdkRectangle *area)
{
	guint x1, y1, x2, y2, x, y;

	if (area) {
		x1 = area->x/MINESIZE;
		y1 = area->y/MINESIZE;
		x2 = (area->x+area->width)/MINESIZE;
		y2 = (area->y+area->height)/MINESIZE;
	} else {
		x1 = 0; y1 = 0;
		x2 = mfield->xsize;
		y2 = mfield->ysize;
	}
	
	for (x = x1; x<=x2; x++) {
		for (y = y1; y<=y2; y++) {
			gtk_mine_draw(mfield, x, y);
		}
	}
}

static gint gtk_minefield_expose(GtkWidget *widget,
				 GdkEventExpose *event)
{
        GtkMineField *mfield;
	GdkColor color;
        GdkFont  *font;
	int i;
	
	g_return_val_if_fail(widget != NULL, FALSE);
        g_return_val_if_fail(GTK_IS_MINEFIELD(widget), FALSE);
        g_return_val_if_fail(event != NULL, FALSE);

	if (!GTK_WIDGET_DRAWABLE(widget))
                return FALSE;

        mfield = GTK_MINEFIELD(widget);
	
	if (mfield->numstr[0].gc == 0) {
		mfield->font = gdk_font_load("-misc-fixed-bold-r-normal--13-*-*-*-*-*-*");
                if (!mfield->font) mfield->font = widget->style->font;
		for (i=0; i<9; i++) {
			mfield->numstr[i].text[0] = i+'0';
			mfield->numstr[i].text[1] = '\0';
			mfield->numstr[i].dx =
				(MINESIZE-gdk_string_width(mfield->font,
							   mfield->numstr[i].text))/2;
			mfield->numstr[i].dy = (MINESIZE-mfield->font->ascent)/2
				+10;
			mfield->numstr[i].gc = gdk_gc_new(GTK_WIDGET(mfield)->window);
			color.pixel  = gnome_colors_get_pixel(num_colors[i][0], /* R */
							      num_colors[i][1], /* G */
							      num_colors[i][2]);
			gdk_gc_set_foreground(mfield->numstr[i].gc, &color);
		}
	}

	gtk_minefield_draw(GTK_MINEFIELD(widget), &event->area);

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
                            mfield->mines[c].marked == 0) {
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
	gint cx1,cy1,cx2,cy2;
	
	cx1 = x-2;
	cy1 = y-2;
	cx2 = x+2;
	cy2 = y+2;

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

static void gtk_minefield_loose(GtkMineField *mfield)
{
        gtk_signal_emit(GTK_OBJECT(mfield),
                        minefield_signals[EXPLODE_SIGNAL]);
        mfield->lose = 1;
        gtk_minefield_draw(mfield, NULL);
}

static void gtk_minefield_win(GtkMineField *mfield)
{
        gtk_signal_emit(GTK_OBJECT(mfield),
                        minefield_signals[WIN_SIGNAL]);
        mfield->win = 1;
}

static void gtk_minefield_show(GtkMineField *mfield, guint x, guint y)
{
	int c = x+mfield->xsize*y;
	
        if (mfield->mines[c].marked != 1 && mfield->mines[c].shown != 1) {
		mfield->mines[c].shown = 1;
		mfield->shown++;
                gtk_mine_draw(mfield, mfield->cdownx, mfield->cdowny);
                if(mfield->mines[c].mined == 1) {
                        gtk_minefield_loose(mfield);
                } else {
			gtk_minefield_check_field(mfield, x, y);
			if (mfield->flags+mfield->shown == mfield->xsize*mfield->ysize) {
                                gtk_minefield_win(mfield);
			}
		}
        }
}

static void gtk_minefield_toggle_mark(GtkMineField *mfield, guint x, guint y)
{
        int c = cell_idx(mfield, x, y);
        if (mfield->mines[c].shown == 0) {
		if ((mfield->mines[c].marked = 1-mfield->mines[c].marked) == 1) {
			mfield->flags++;
		} else {
			mfield->flags--;
		}
		gtk_signal_emit(GTK_OBJECT(mfield),
				minefield_signals[MARKS_CHANGED_SIGNAL]);
		if (mfield->flags+mfield->shown == mfield->xsize*mfield->ysize) {
                        gtk_minefield_win(mfield);
		}
        }
}

static inline void gtk_minefield_multi_press(GtkMineField *mfield, guint x, guint y, gint c)
{
        guint n, i;
        gint nx, ny, c2;

        n = 0;
        for (i=0; i<8; i++) {
                nx = x+neighbour_map[i].x;
                ny = y+neighbour_map[i].y;
                if ((c2 = cell_idx(mfield, nx, ny)) == -1)
                        continue;
                if (mfield->mines[c2].marked) n++;
        }
        if (mfield->mines[c].neighbours == n) {
                for (i=0; i<8; i++) {
                        nx = x+neighbour_map[i].x;
                        ny = y+neighbour_map[i].y;
                        if ((c2 = cell_idx(mfield, nx, ny)) == -1)
                                continue;
                        if (!mfield->mines[c2].marked &&
                            !mfield->mines[c2].shown) {
                                mfield->mines[c2].down = 1;
                                gtk_mine_draw(mfield, nx, ny);
                        }
                }
                mfield->multi_mode = 1;
        }
}

static void gtk_minefield_multi_release (GtkMineField *mfield, guint x, guint y, guint really)
{
        gint nx, ny, i, c2;
        guint loose = 0;

        mfield->multi_mode = 0;
        
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
                                        loose = 1;
                                }
                        }
                        gtk_mine_draw(mfield, nx ,ny);
                }
        }
        if (loose) {
                gtk_minefield_loose(mfield);
        } else if (really) {
                gtk_minefield_check_field(mfield, x, y);
		if (mfield->flags+mfield->shown == mfield->xsize*mfield->ysize) {
			gtk_minefield_win(mfield);
		}
        }
}

static gint gtk_minefield_button_press(GtkWidget *widget, GdkEventButton *event)
{
        GtkMineField *mfield;
	guint x, y;
	guint c,c2;
	guint i,n;
	gint nx, ny;
        
        g_return_val_if_fail(widget != NULL, 0);
        g_return_val_if_fail(GTK_IS_MINEFIELD(widget), 0);
        g_return_val_if_fail(event != NULL, 0);

        mfield = GTK_MINEFIELD(widget);

	if (mfield->lose || mfield->win) return FALSE;
	
        if (!mfield->bdown) {
                x = event->x/MINESIZE;
                y = event->y/MINESIZE;
                c = x+y*(mfield->xsize);
                mfield->cdownx = x;
                mfield->cdowny = y;
                mfield->cdown = c;
                mfield->mines[c].down = 1;
		mfield->bdown = event->button;
		gtk_mine_draw(mfield, x, y);
		if (event->button == 2 && mfield->mines[c].shown == 1) { /* multi show */
                        gtk_minefield_multi_press(mfield, x, y, c);
		}
		if (event->button == 1 || event->button == 2) {
			gtk_signal_emit(GTK_OBJECT(mfield),
					minefield_signals[LOOK_SIGNAL]);
		}
        }
        return FALSE;
}

static gint gtk_minefield_button_release(GtkWidget *widget, GdkEventButton *event)
{
        GtkMineField *mfield;
	guint x, y;

        g_return_val_if_fail(widget != NULL, FALSE);
        g_return_val_if_fail(GTK_IS_MINEFIELD(widget), FALSE);
        g_return_val_if_fail(event != NULL, FALSE);

	mfield = GTK_MINEFIELD(widget);

	if (mfield->lose || mfield->win) return FALSE;

        if (event->button == mfield->bdown) {
                x = event->x/MINESIZE;
                y = event->y/MINESIZE;
		if (x+y*(mfield->xsize) == mfield->cdown) {
                        switch (event->button) {
			case 1: gtk_minefield_show(mfield, x, y);
                                break;
			case 2: if (mfield->multi_mode) gtk_minefield_multi_release(mfield, x, y, 1);

                                break;
                        case 3: gtk_minefield_toggle_mark(mfield, x, y);
                                break;
			}
                } else if (mfield->multi_mode) {
                        gtk_minefield_multi_release(mfield, mfield->cdownx, mfield->cdowny, 0);
		}
		if (!mfield->lose && !mfield->win) {
			gtk_signal_emit(GTK_OBJECT(mfield),
					minefield_signals[UNLOOK_SIGNAL]);
		}
		mfield->mines[mfield->cdown].down = 0;
                mfield->cdown = -1;
		mfield->bdown = 0;
		gtk_mine_draw(mfield, mfield->cdownx, mfield->cdowny);
        }
        return FALSE;
}


static void gtk_minefield_class_init (GtkMineFieldClass *class)
{
	GtkWidgetClass *widget_class;
	GtkObjectClass *object_class;
	
        widget_class = (GtkWidgetClass *)class;
	object_class = (GtkObjectClass *)class;
	
        widget_class->realize = gtk_minefield_realize;
        widget_class->size_allocate = gtk_minefield_size_allocate;
        widget_class->size_request = gtk_minefield_size_request;
        widget_class->expose_event = gtk_minefield_expose;
        widget_class->button_press_event = gtk_minefield_button_press;
	widget_class->button_release_event = gtk_minefield_button_release;
	minefield_signals[MARKS_CHANGED_SIGNAL] =
		gtk_signal_new("marks_changed",
			       GTK_RUN_FIRST,
			       object_class->type,
			       GTK_SIGNAL_OFFSET(GtkMineFieldClass, marks_changed),
			       gtk_signal_default_marshaller,
			       GTK_TYPE_NONE,
			       0);
	minefield_signals[EXPLODE_SIGNAL] =
		gtk_signal_new("explode",
			       GTK_RUN_FIRST,
			       object_class->type,
			       GTK_SIGNAL_OFFSET(GtkMineFieldClass, explode),
			       gtk_signal_default_marshaller,
			       GTK_TYPE_NONE,
			       0);
	minefield_signals[LOOK_SIGNAL] =
		gtk_signal_new("look",
			       GTK_RUN_FIRST,
			       object_class->type,
			       GTK_SIGNAL_OFFSET(GtkMineFieldClass, look),
			       gtk_signal_default_marshaller,
			       GTK_TYPE_NONE,
			       0);
	minefield_signals[UNLOOK_SIGNAL] =
		gtk_signal_new("unlook",
			       GTK_RUN_FIRST,
			       object_class->type,
			       GTK_SIGNAL_OFFSET(GtkMineFieldClass, unlook),
			       gtk_signal_default_marshaller,
			       GTK_TYPE_NONE,
			       0);
	minefield_signals[WIN_SIGNAL] =
		gtk_signal_new("win",
			       GTK_RUN_FIRST,
			       object_class->type,
			       GTK_SIGNAL_OFFSET(GtkMineFieldClass, win),
			       gtk_signal_default_marshaller,
			       GTK_TYPE_NONE,
			       0);

	gtk_object_class_add_signals(object_class, minefield_signals, LAST_SIGNAL);
	

}

static void gtk_minefield_init (GtkMineField *mfield)
{
        GTK_WIDGET_SET_FLAGS (mfield, GTK_BASIC);
        mfield->xsize = 0;
        mfield->ysize = 0;
        
        GTK_WIDGET (mfield)->requisition.width = MINESIZE;
        GTK_WIDGET (mfield)->requisition.height = MINESIZE;
}

void gtk_minefield_set_size(GtkMineField *mfield, guint xsize, guint ysize)
{
	if (mfield->xsize*mfield->ysize != xsize*ysize) {
		mfield->mines = g_realloc(mfield->mines,
					  sizeof(mine)*xsize*ysize);
	}
	mfield->xsize = xsize;
	mfield->ysize = ysize;
}

GtkWidget* gtk_minefield_new(void)
{
        GtkMineField *mfield;
        GtkWidget *widget;
	int i;
        
	mfield = gtk_type_new(gtk_minefield_get_type());
	widget = GTK_WIDGET(mfield);
	mfield->mines = NULL;
	gtk_minefield_set_size(mfield, 0, 0);

	mfield->cdown = -1;
	mfield->numstr[0].gc = 0; /* Force GC generation */
	return GTK_WIDGET(mfield);
}

guint gtk_minefield_get_type ()
{
        static guint minefield_type = 0;
        
        if (!minefield_type)
        {
                GtkTypeInfo minefield_info =
                        {
                                "GtkMineField",
                                sizeof (GtkMineField),
                                sizeof (GtkMineFieldClass),
                                (GtkClassInitFunc) gtk_minefield_class_init,
                                (GtkObjectInitFunc) gtk_minefield_init,
                                (GtkArgFunc) NULL,
                        };
                        
                        minefield_type = gtk_type_unique (gtk_widget_get_type (), &minefield_info);
        }
        
        return minefield_type;
}

void gtk_minefield_set_mines(GtkMineField *mfield, guint mcount)
{
        mfield->mcount = mcount;
}

static gulong random_seed;

void init_random(gulong seed)
{
        random_seed = seed;
}

gulong get_random(gulong limit)
{
	do {
		random_seed = (random_seed*1139113+10921)>>2;
	} while (random_seed > ((gulong)(G_MAXLONG/limit))*limit);
	return random_seed % limit;
}

void gtk_minefield_restart(GtkMineField *mfield)
{
	guint i, j;
        guint x, y;
	guint tmp;
	guint n;
	guint cidx;

	mfield->flags = 0;
	mfield->shown = 0;
	mfield->lose  = 0;
	mfield->win   = 0;
	mfield->bdown = 0;
        mfield->cdown = -1;
        mfield->multi_mode = 0;

	for (i=0; i<mfield->mcount; i++) {
		mfield->mines[i].mined = 1;
	}
	for (i=mfield->mcount; i<mfield->xsize*mfield->ysize; i++) {
		mfield->mines[i].mined = 0;
	}

	if (secs == 0) {
		time((time_t *)&secs);
		init_random(secs);
	}
			
	
	for (i=0; i<mfield->xsize*mfield->ysize; i++) {
                mfield->mines[i].marked = 0;
                mfield->mines[i].shown  = 0;
		mfield->mines[i].down   = 0;
		j = (guint)get_random(mfield->xsize*mfield->ysize);
		tmp = mfield->mines[i].mined;
		mfield->mines[i].mined = mfield->mines[j].mined;
		mfield->mines[j].mined = tmp;
	}

	for (x=0; x<mfield->xsize; x++) {
		for (y=0; y<mfield->ysize; y++) {
			n = 0;
			for (i=0; i<8; i++) {
				if ((cidx = cell_idx(mfield, x+neighbour_map[i].x,
						     y+neighbour_map[i].y)) != -1) {
					if (mfield->mines[cidx].mined) n++;
				}
			}
                        mfield->mines[x+mfield->xsize*y].neighbours = n;
		}
	}
}

