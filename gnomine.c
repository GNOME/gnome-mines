/* -*- mode:C; tab-width:8; c-basic-offset:8; indent-tabs-mode:true -*- */

/*
 *
 * Author:        Pista <szekeres@cyberspace.mht.bme.hu>
 *
 * Score support: horape@compendium.com.ar
 * Mine Resizing: djb@redhat.com
 *
 */
#include <config.h>
#include <gnome.h>
#include <libgnomeui/gnome-window-icon.h>
#include <gconf/gconf-client.h>
#include <string.h>

#include "minefield.h"
#include "games-clock.h"
#include "games-frame.h"

/* Limits for various minefield properties */
#define MINESIZE_MIN 2
#define MINESIZE_MAX 100
#define XSIZE_MIN 4
#define XSIZE_MAX 100
#define YSIZE_MIN 4
#define YSIZE_MAX 100

/* GConf key paths */
#define KEY_DIR "/apps/gnomine"
#define KEY_XSIZE "/apps/gnomine/geometry/xsize"
#define KEY_YSIZE "/apps/gnomine/geometry/ysize"
#define KEY_NMINES "/apps/gnomine/geometry/nmines"
#define KEY_MINESIZE "/apps/gnomine/geometry/minesize"
#define KEY_MODE "/apps/gnomine/geometry/mode"
#define KEY_USE_QUESTION_MARKS "/apps/gnomine/use_question_marks"

static GtkWidget *mfield;
static GtkWidget *pref_dialog;
static GtkWidget *rbutton;
static GtkWidget *ralign;
static GConfClient *conf_client;
GtkWidget *window;
GtkWidget *flabel;
GtkWidget *xentry;
GtkWidget *yentry;
GtkWidget *mentry;
GtkWidget *sentry;
GtkWidget *question_toggle;
GtkWidget *mbutton;
GtkWidget *plabel;
GtkWidget *cframe;
GtkWidget *clk;
GtkWidget *pm_win, *pm_sad, *pm_smile, *pm_cool, *pm_worried, *pm_current;
GtkWidget *face_box;
gint ysize = -1, xsize = -1;
gint nmines = -1;
gint fsize = -1;
gint minesize = -1;
gboolean use_question_marks = TRUE;

GnomeUIInfo gamemenu[];
GnomeUIInfo settingsmenu[];
GnomeUIInfo helpmenu[];
GnomeUIInfo mainmenu[];

char *fsize2names[] = {
	N_("Small"),
	N_("Medium"),
	N_("Large"),
	N_("Custom"),
};

static GtkWidget *
image_widget_setup (char *name)
{
	GdkPixbuf *pixbuf = NULL;
	char *filename = NULL;
	GtkWidget * l;

	filename = gnome_program_locate_file (NULL,
			GNOME_FILE_DOMAIN_APP_PIXMAP, name,
			TRUE, NULL);
	if (filename != NULL)
		pixbuf = gdk_pixbuf_new_from_file (filename, NULL);

	g_free (filename);

	return gtk_image_new_from_pixbuf (pixbuf);
}

void show_face(GtkWidget *pm)
{
        if (pm_current == pm) return;

	if (pm_current) {
		gtk_widget_hide(pm_current); 
	}

	gtk_widget_show(pm);
	
	pm_current = pm;
}

void quit_game(GtkWidget *widget, gpointer data)
{
	gtk_main_quit();
}

void set_flabel(GtkMineField *mfield)
{
	char *val;

	val = g_strdup_printf ("%d/%d", mfield->flag_count, mfield->mcount);
	gtk_label_set_text (GTK_LABEL(flabel), val);
}

void update_score_state ()
{
        gchar **names = NULL;
        gfloat *scores = NULL;
       time_t *scoretimes = NULL;
	gint top;
	gchar buf[64];

	if(fsize<4)
		strncpy(buf, fsize2names[fsize], sizeof(buf));

	top = gnome_score_get_notable("gnomine", buf, &names, &scores, &scoretimes);
	if (top > 0) {
		gtk_widget_set_sensitive (gamemenu[2].widget, TRUE);
		g_strfreev(names);
		g_free(scores);
		g_free(scoretimes);
	} else {
		gtk_widget_set_sensitive (gamemenu[2].widget, FALSE);
	}
}

void
show_scores (gchar *level, guint pos)
{
	gnome_scores_display (_("GNOME Mines"), "gnomine", level, pos);
}

void top_ten(GtkWidget *widget, gpointer data)
{
	gchar buf[64];

	if(fsize<4)
		strncpy(buf, fsize2names[fsize], sizeof(buf));

	show_scores(buf, 0);
}

void new_game(GtkWidget *widget, gpointer data)
{
	games_clock_stop(GAMES_CLOCK(clk));
	games_clock_set_seconds(GAMES_CLOCK(clk), 0);

	show_face(pm_smile);
	gtk_minefield_restart(GTK_MINEFIELD(mfield));
	set_flabel(GTK_MINEFIELD(mfield));

	gtk_widget_hide (ralign);
	gtk_widget_show (mfield);
}

gint
configure_cb (GtkWidget *widget, GdkEventConfigure *event)
{
#if 0
	/* FIXME: resize mines to fix window */
	/* Need to resize mines when grid changes too */
	gint mxsize, mysize, size;
	mxsize = event->width / xsize;
	mysize = event->height / ysize;
	size = MIN (mxsize, mysize);
	gconf_client_set_int (conf_client, KEY_MINESIZE,
			      size, NULL);
#endif
	return FALSE;
}

void focus_out_cb (GtkWidget *widget, GdkEventFocus *event, gpointer data)
{
        GtkRequisition req;

	if (GAMES_CLOCK(clk)->timer_id == -1)
		return;

        /* This is a complete abuse of the sizing system, but it seems to
         * be the only way to keep the window the same size when we substitute
         * the "Press to resume" button, but still allow it to resize when we 
         * resize the field. */
        gtk_widget_size_request (mfield, &req);
        gtk_widget_set_size_request (ralign, req.width, req.height);
	gtk_widget_hide (mfield);
	gtk_widget_show (ralign);

	gtk_widget_grab_focus(rbutton);

	games_clock_stop(GAMES_CLOCK(clk)); 
}

void resume_game_cb (GtkButton *widget, gpointer data)
{
	gtk_widget_hide (ralign);
	gtk_widget_show (mfield);

	games_clock_start(GAMES_CLOCK(clk));
}

void marks_changed(GtkWidget *widget, gpointer data)
{
        set_flabel(GTK_MINEFIELD(widget));

	games_clock_start(GAMES_CLOCK(clk));
}

void lose_game(GtkWidget *widget, gpointer data)
{
        show_face(pm_sad);

	gtk_widget_grab_focus(mbutton);

        games_clock_stop(GAMES_CLOCK(clk));
}

void win_game(GtkWidget *widget, gpointer data)
{
        gfloat score;
        int pos;
        gchar buf[64];


        games_clock_stop(GAMES_CLOCK(clk));

	gtk_widget_grab_focus(mbutton);

        show_face(pm_win);

	if(fsize<4) {
	    score = (gfloat) (GAMES_CLOCK(clk)->stopped / 60) + 
		    (gfloat) (GAMES_CLOCK(clk)->stopped % 60) / 100;

            strncpy(buf, fsize2names[fsize], sizeof(buf));
	    pos = gnome_score_log(score, buf, FALSE);
	} else {
	    score = ((nmines * 100) / (xsize * ysize)) /
		    (gfloat) (GAMES_CLOCK(clk)->stopped); 

            strncpy(buf, fsize2names[fsize], sizeof(buf));
	    pos = gnome_score_log(score, buf, TRUE);
	}

	update_score_state ();

	show_scores(buf, pos);
}

void look_cell(GtkWidget *widget, gpointer data)
{
        show_face(pm_worried);

        games_clock_start(GAMES_CLOCK(clk));
}

void unlook_cell(GtkWidget *widget, gpointer data)
{
	show_face(pm_cool);
}

void setup_mode(GtkWidget *widget, gint mode)
{
	gint size_table[3][3] = {{ 8, 8, 10 }, {16, 16, 40}, {30, 16, 99}};
	gint x,y,m,s;

	if (mode == 3) {
		x = xsize;
		y = ysize;
		m = nmines;
	} else {
		x = size_table[mode][0];
		y = size_table[mode][1];
		m = size_table[mode][2];
	}
	s = minesize;
	gtk_minefield_set_size(GTK_MINEFIELD(mfield), x, y);
	gtk_minefield_set_mines(GTK_MINEFIELD(mfield), m, s);
}

int range (int val, int min, int max)
{
	if (val < min)
		val = min;
	if (val > max)
		val = max;
	return val;
}


void verify_ranges (void)
{
	minesize = range (minesize, MINESIZE_MIN, MINESIZE_MAX);
	xsize    = range (xsize, XSIZE_MIN, XSIZE_MAX);
	ysize    = range (ysize, YSIZE_MIN, YSIZE_MAX);
	nmines   = range (nmines, 1, xsize * ysize);
}

void
about(GtkWidget *widget, gpointer data)
{
        static GtkWidget *about;
	GdkPixbuf *pixbuf = NULL;

        const gchar *authors[] = {
		_("Main game:"),
		"Szekeres Istvan",
		"",
		_("Faces:"),
		"Tuomas Kuosmanen",
		"",
		_("Score:"),
		"Horacio J. Pe\xc3\xb1""a",
		NULL
	};
	const gchar *documenters[] = {
                NULL
        };
	const gchar *translator_credits = _("translator_credits");
	
	if (about) {
                gtk_window_present (GTK_WINDOW (about));
		return;
	}

       {
            int i=0;
            while (authors[i] != NULL) { authors[i]=_(authors[i]); i++; }
       }
       {
	       char *filename = NULL;

	       filename = gnome_program_locate_file (NULL,
			       GNOME_FILE_DOMAIN_APP_PIXMAP,  ("gnome-gnomine.png"),
			       TRUE, NULL);
	       if (filename != NULL)
	       {
		       pixbuf = gdk_pixbuf_new_from_file(filename, NULL);
		       g_free (filename);
	       }
       }

        about = gnome_about_new (_("GNOME Mines"), VERSION,
				 "Copyright \xc2\xa9 1997-2003 Free Software "
				 "Foundation, Inc.",
				 _("A Minesweeper clone."),
				 (const char **)authors,
				 (const char **)documenters,
				 strcmp (translator_credits, "translator_credits") != 0 ? translator_credits : NULL,
				 pixbuf);
	
	if (pixbuf != NULL)
		gdk_pixbuf_unref (pixbuf);
	
	g_signal_connect (GTK_OBJECT (about), "destroy", GTK_SIGNAL_FUNC
			(gtk_widget_destroyed), &about);
	gtk_window_set_transient_for(GTK_WINDOW (about), GTK_WINDOW (window));
        gtk_widget_show (about);
}

static void
gconf_key_change_cb (GConfClient *client, guint cnxn_id,
		     GConfEntry *entry, gpointer user_data)
{
	const char *key;
	GConfValue *value;
    
	key = gconf_entry_get_key (entry);
	value = gconf_entry_get_value (entry);

	if (strcmp (key, KEY_XSIZE) == 0) {
		int i;
		i = value ? gconf_value_get_int (value) : 16;
		if (i != xsize) {
			xsize = range (i, XSIZE_MIN, XSIZE_MAX);
			gtk_minefield_set_size(GTK_MINEFIELD(mfield), xsize, ysize);
			new_game (mfield, NULL);
		}
	}
	if (strcmp (key, KEY_YSIZE) == 0) {
		int i;
		i = value ? gconf_value_get_int (value) : 16;
		if (i != ysize) {
			ysize = range (i, YSIZE_MIN, YSIZE_MAX);
			gtk_minefield_set_size(GTK_MINEFIELD(mfield), xsize, ysize);
			new_game (mfield, NULL);
		}
	}
	if (strcmp (key, KEY_NMINES) == 0) {
		int i;
		i = value ? gconf_value_get_int (value) : 40;
		if (nmines != i) {
			nmines = range (i, 1, xsize * ysize - 2);
			gtk_minefield_set_mines(GTK_MINEFIELD(mfield), nmines, minesize);
			new_game (mfield, NULL);
		}
	}
	if (strcmp (key, KEY_MINESIZE) == 0) {
		int i;
		i = value ? gconf_value_get_int (value) : 17;
		if (minesize != i) {
			minesize = range (i, MINESIZE_MIN, MINESIZE_MAX);
			gtk_minefield_set_mines(GTK_MINEFIELD(mfield), nmines, minesize);
		}
	}
	if (strcmp (key, KEY_MODE) == 0) {
		int i;
		i = value ? gconf_value_get_int (value) : 0;
		if (i != fsize) {
			fsize = i;
			setup_mode (mfield, fsize);
			update_score_state ();
			new_game (mfield, NULL);
		}
	}
	if (strcmp (key, KEY_USE_QUESTION_MARKS) == 0) {
		use_question_marks = value ? gconf_value_get_bool (value) : TRUE;
		gtk_minefield_set_use_question_marks(GTK_MINEFIELD(mfield), use_question_marks);
	}
}

static void
size_radio_callback(GtkWidget *widget, gpointer data)
{
	int fsc;
	if (!pref_dialog)
		return;

	fsc = GPOINTER_TO_INT (data);

	gconf_client_set_int (conf_client, KEY_MODE,
			fsc, NULL);

	gtk_widget_set_sensitive(cframe, fsc == 3);
}

void fix_nmines (int xsize, int ysize)
{
  int maxmines;

  /* Fix up the maximum number of mines so that there is always at least two
   * free spaces. It could in theory be left at one, but that gives an
   * instant win situation. */
  maxmines = xsize*ysize - 2;
  if (nmines > maxmines) {
    gconf_client_set_int (conf_client, KEY_NMINES, maxmines, NULL);
    gtk_spin_button_set_value (GTK_SPIN_BUTTON(mentry), maxmines);
  }
  gtk_spin_button_set_range (GTK_SPIN_BUTTON(mentry), 1, maxmines);
}

static void
xsize_spin_cb (GtkSpinButton *spin, gpointer data)
{
	int size = gtk_spin_button_get_value_as_int (spin);
	gconf_client_set_int (conf_client, KEY_XSIZE,
			      size, NULL);
        fix_nmines(size,ysize);
}

static void
ysize_spin_cb (GtkSpinButton *spin, gpointer data)
{
	int size = gtk_spin_button_get_value_as_int (spin);
	gconf_client_set_int (conf_client, KEY_YSIZE,
			      size, NULL);
        fix_nmines(xsize,size);
}

static void
nmines_spin_cb (GtkSpinButton *spin, gpointer data)
{
	int size = gtk_spin_button_get_value_as_int (spin);
	gconf_client_set_int (conf_client, KEY_NMINES,
			      size, NULL);

}

static void
minesize_spin_cb (GtkSpinButton *spin, gpointer data)
{
	int size = gtk_spin_button_get_value_as_int (spin);
	gconf_client_set_int (conf_client, KEY_MINESIZE,
			      size, NULL);

}

static void
use_question_toggle_cb (GtkCheckButton *check, gpointer data)
{
	gboolean use_marks = gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(check));
	gconf_client_set_bool (conf_client, KEY_USE_QUESTION_MARKS,
				use_marks, NULL);
}

static void preferences_callback (GtkWidget *widget, gpointer data)
{
	GtkWidget *table;
	GtkWidget *frame;
	GtkWidget *vbox;
	GtkWidget *hbox;
	GtkWidget *button;
	GtkWidget *table2;
	GtkWidget *label2;
	char *numstr;
        
	if (pref_dialog) {
                gtk_window_present (GTK_WINDOW (pref_dialog));
		return;
        }

	table = gtk_table_new (2, 3, FALSE);
	gtk_container_set_border_width (GTK_CONTAINER (table), GNOME_PAD);
	gtk_table_set_row_spacings (GTK_TABLE (table), GNOME_PAD);
	gtk_table_set_col_spacings (GTK_TABLE (table), GNOME_PAD);

	frame = games_frame_new (_("Field size"));

	vbox = gtk_vbox_new (TRUE, 0);
	gtk_container_set_border_width (GTK_CONTAINER (vbox), GNOME_PAD);

	button = gtk_radio_button_new_with_label(NULL, _("Small"));
	if (fsize == 0)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "clicked",
			GTK_SIGNAL_FUNC (size_radio_callback), (gpointer) 0);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);

	button = gtk_radio_button_new_with_label
		(gtk_radio_button_get_group (GTK_RADIO_BUTTON(button)),
		 _("Medium"));
	if (fsize == 1)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "clicked",
			GTK_SIGNAL_FUNC (size_radio_callback), (gpointer) 1);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);

	button = gtk_radio_button_new_with_label
		(gtk_radio_button_get_group (GTK_RADIO_BUTTON (button)),
		 _("Large"));
	if (fsize == 2)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "clicked",
			GTK_SIGNAL_FUNC (size_radio_callback), (gpointer) 2);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
	
	button = gtk_radio_button_new_with_label
		(gtk_radio_button_get_group(GTK_RADIO_BUTTON(button)),
		 _("Custom"));
	if (fsize == 3)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	g_signal_connect (GTK_OBJECT (button), "clicked",
			GTK_SIGNAL_FUNC (size_radio_callback), (gpointer) 3);
	gtk_box_pack_start (GTK_BOX (vbox), button, TRUE, TRUE, 0);

	gtk_container_add (GTK_CONTAINER (frame), vbox);

	gtk_table_attach (GTK_TABLE (table), frame, 0, 1, 0, 1, GTK_EXPAND |
			GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);

	cframe = games_frame_new (_("Custom size"));
	gtk_widget_set_sensitive (cframe, fsize == 3);

	table2 = gtk_table_new (3, 2, FALSE);
	gtk_container_set_border_width (GTK_CONTAINER (table2), GNOME_PAD);
	gtk_table_set_row_spacings (GTK_TABLE (table2), GNOME_PAD);

	label2 = gtk_label_new (_("Number of mines:"));
	gtk_misc_set_alignment (GTK_MISC (label2), 0, 0.5);
	gtk_table_attach (GTK_TABLE (table2), label2, 0, 1, 2, 3,
			GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);
	/* TODO: fix this when gconfised correctly */
	mentry = gtk_spin_button_new_with_range (1, XSIZE_MAX*YSIZE_MAX, 1);
	g_signal_connect (GTK_OBJECT (mentry), "value-changed",
			GTK_SIGNAL_FUNC (nmines_spin_cb), NULL);
	gtk_spin_button_set_value (GTK_SPIN_BUTTON(mentry), nmines);
	gtk_table_attach (GTK_TABLE (table2), mentry, 1, 2, 2, 3, GTK_FILL, GTK_EXPAND
			| GTK_FILL, 0, 0);

	label2 = gtk_label_new (_("Horizontal:"));
	gtk_misc_set_alignment (GTK_MISC (label2), 0, 0.5);
	gtk_table_attach (GTK_TABLE (table2), label2, 0, 1, 0, 1,
			GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);

	xentry = gtk_spin_button_new_with_range (XSIZE_MIN, XSIZE_MAX, 1);
	g_signal_connect (GTK_OBJECT (xentry), "value-changed",
			GTK_SIGNAL_FUNC (xsize_spin_cb), NULL);
	gtk_spin_button_set_value (GTK_SPIN_BUTTON(xentry), xsize);
	gtk_table_attach (GTK_TABLE (table2), xentry, 1, 2, 0, 1, 0, GTK_EXPAND
			| GTK_FILL, 0, 0);

	label2 = gtk_label_new (_("Vertical:"));
	gtk_misc_set_alignment (GTK_MISC (label2), 0, 0.5);
	gtk_table_attach (GTK_TABLE (table2), label2, 0, 1, 1, 2,
			GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);

	yentry = gtk_spin_button_new_with_range (YSIZE_MIN, YSIZE_MAX, 1);
	g_signal_connect (GTK_OBJECT (yentry), "value-changed",
			GTK_SIGNAL_FUNC (ysize_spin_cb), NULL);
	gtk_spin_button_set_value (GTK_SPIN_BUTTON(yentry), ysize);
	gtk_table_attach (GTK_TABLE (table2), yentry, 1, 2, 1, 2, 0, GTK_EXPAND
			| GTK_FILL, 0, 0);

	gtk_container_add (GTK_CONTAINER (cframe), table2);

	gtk_table_attach (GTK_TABLE (table), cframe, 1, 2, 0, 1, GTK_EXPAND |
			GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);

	hbox = gtk_hbox_new (FALSE, GNOME_PAD);

	label2 = gtk_label_new(_("Mine size:"));
	gtk_box_pack_start (GTK_BOX (hbox), label2, FALSE, FALSE, 0);

	sentry = gtk_spin_button_new_with_range(MINESIZE_MIN, MINESIZE_MAX, 1);
	g_signal_connect (GTK_OBJECT (sentry), "value-changed",
			GTK_SIGNAL_FUNC (minesize_spin_cb), NULL);
	gtk_spin_button_set_value (GTK_SPIN_BUTTON(sentry), minesize);
	gtk_box_pack_start (GTK_BOX (hbox), sentry, TRUE, TRUE, 0);

	gtk_table_attach (GTK_TABLE (table), hbox, 0, 1, 1, 2, GTK_EXPAND |
			GTK_FILL, 0, 0, 0);

	question_toggle = gtk_check_button_new_with_label(_("Use \"I'm not sure\" flags."));
	g_signal_connect(GTK_OBJECT(question_toggle), "toggled",
			GTK_SIGNAL_FUNC (use_question_toggle_cb), NULL);
	gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(question_toggle), use_question_marks);
	gtk_widget_show(question_toggle);
	
	gtk_table_attach (GTK_TABLE (table), question_toggle, 0, 2, 2, 3, GTK_EXPAND | GTK_FILL, 0, 0, 0);


	pref_dialog = gtk_dialog_new_with_buttons (_("GNOME Mines Preferences"),
			GTK_WINDOW (window),
			0,
			GTK_STOCK_CLOSE, GTK_RESPONSE_CLOSE,
			NULL);

        gtk_dialog_set_has_separator (GTK_DIALOG (pref_dialog), FALSE);
	gtk_container_add (GTK_CONTAINER(GTK_DIALOG(pref_dialog)->vbox),
			table);

	g_signal_connect (GTK_OBJECT (pref_dialog), "destroy",
			GTK_SIGNAL_FUNC (gtk_widget_destroyed), &pref_dialog);
	g_signal_connect (GTK_OBJECT (pref_dialog), "response",
			GTK_SIGNAL_FUNC (gtk_widget_destroy), &pref_dialog);

	gtk_widget_show_all (pref_dialog);
}

GnomeUIInfo gamemenu[] = {
        GNOMEUIINFO_MENU_NEW_GAME_ITEM(new_game, NULL),
	GNOMEUIINFO_SEPARATOR,
	GNOMEUIINFO_MENU_SCORES_ITEM(top_ten, NULL),
	GNOMEUIINFO_SEPARATOR,
	GNOMEUIINFO_MENU_QUIT_ITEM(quit_game, NULL),
	GNOMEUIINFO_END
};

GnomeUIInfo settingsmenu[] = {
	GNOMEUIINFO_MENU_PREFERENCES_ITEM(preferences_callback, NULL),
	GNOMEUIINFO_END
};

GnomeUIInfo helpmenu[] = {
        GNOMEUIINFO_HELP("gnomine"),
	GNOMEUIINFO_MENU_ABOUT_ITEM(about, NULL),
	GNOMEUIINFO_END
};

GnomeUIInfo mainmenu[] = {
        GNOMEUIINFO_MENU_GAME_TREE(gamemenu),
	GNOMEUIINFO_MENU_SETTINGS_TREE(settingsmenu),
        GNOMEUIINFO_MENU_HELP_TREE(helpmenu),
	GNOMEUIINFO_END
};

/* A little helper function.  */
static char *
nstr (int n)
{
	char *buf;

	buf = g_strdup_printf ("%d", n);
	return buf;
}

static int
save_state (GnomeClient        *client,
	    gint                phase,
	    GnomeRestartStyle   save_style,
	    gint                shutdown,
	    GnomeInteractStyle  interact_style,
	    gint                fast,
	    gpointer            client_data)
{
	char *argv[20];
	int i = 0, j;
	gint xpos, ypos;

	gdk_window_get_origin (window->window, &xpos, &ypos);

	argv[i++] = (char *) client_data;
	argv[i++] = "-x";
	argv[i++] = nstr (xsize);
	argv[i++] = "-y";
	argv[i++] = nstr (ysize);
	argv[i++] = "-n";
	argv[i++] = nstr (nmines);
	argv[i++] = "-f";
	argv[i++] = nstr (fsize);
	argv[i++] = "-a";
	argv[i++] = nstr (xpos);
	argv[i++] = "-b";
	argv[i++] = nstr (ypos);

	gnome_client_set_restart_command (client, i, argv);
	/* i.e. clone_command = restart_command - '--sm-client-id' */
	gnome_client_set_clone_command (client, 0, NULL);

	for (j = 2; j < i; j += 2)
		free (argv[j]);

	return TRUE;
}



static int xpos = -1, ypos = -1;

static struct poptOption options[] = {
  {NULL, 'x', POPT_ARG_INT, &xsize, 0, N_("Width of grid"), N_("X")},
  {NULL, 'y', POPT_ARG_INT, &ysize, 0, N_("Height of grid"), N_("Y")},
  {NULL, 's', POPT_ARG_INT, &minesize, 0, N_("Size of mines"), N_("SIZE")},
  {NULL, 'n', POPT_ARG_INT, &nmines, 0, N_("Number of mines"), N_("NUMBER")},
  {NULL, 'f', POPT_ARG_INT, &fsize, 0, NULL, NULL},
  {NULL, 'a', POPT_ARG_INT, &xpos, 0, NULL, N_("X")},
  {NULL, 'b', POPT_ARG_INT, &ypos, 0, NULL, N_("Y")},
  {NULL, '\0', 0, NULL, 0}
};

int
main (int argc, char *argv[])
{
        GnomeAppBar *appbar;
        GtkWidget *all_boxes;
	GtkWidget *status_box;
	GtkWidget *button_table;
        GtkWidget *align;
        GtkWidget *box;        
        GtkWidget *label;
	GnomeClient *client;

	gnome_score_init("gnomine");

	bindtextdomain (GETTEXT_PACKAGE, GNOMELOCALEDIR);
	bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
	textdomain (GETTEXT_PACKAGE);

	gnome_program_init ("gnomine", VERSION,
			LIBGNOMEUI_MODULE,
			argc, argv,
			GNOME_PARAM_POPT_TABLE, options,
			GNOME_PARAM_APP_DATADIR, DATADIR, NULL);

	/* Get the default GConfClient */
	conf_client = gconf_client_get_default ();
        gconf_client_add_dir (conf_client, 
                              KEY_DIR,
                              GCONF_CLIENT_PRELOAD_RECURSIVE,
                              NULL);
	gconf_client_notify_add (conf_client, KEY_DIR,
				gconf_key_change_cb, NULL, NULL, NULL);

	gnome_window_icon_set_default_from_file (GNOME_ICONDIR"/gnome-gnomine.png");
	client = gnome_master_client ();
	g_signal_connect (GTK_OBJECT (client), "save_yourself",
			    GTK_SIGNAL_FUNC (save_state), argv[0]);

	if (xpos > 0 || ypos > 0)
	  gdk_window_move (GTK_WIDGET(window)->window, xpos, ypos);
		
	if (xsize == -1)
		xsize = gconf_client_get_int (conf_client,
				KEY_XSIZE,
				NULL);
	if (ysize == -1)
		ysize = gconf_client_get_int (conf_client,
				KEY_YSIZE,
				NULL);
	if (nmines == -1)
		nmines = gconf_client_get_int (conf_client,
				KEY_NMINES,
				NULL);
	if (minesize == -1)
		minesize = gconf_client_get_int (conf_client,
				KEY_MINESIZE,
				NULL);
	if (fsize == -1)
		fsize = gconf_client_get_int (conf_client,
				KEY_MODE,
				NULL);
	use_question_marks = gconf_client_get_bool(conf_client, 
				KEY_USE_QUESTION_MARKS,
				NULL);
	
	verify_ranges ();

#define ELEMENTS(x) (sizeof(x) / sizeof(x[0])) 
	{
		int i;
		for (i = 0; i < ELEMENTS(mainmenu); i++)
			mainmenu[i].label = gettext(mainmenu[i].label);
		for (i = 0; i < ELEMENTS(gamemenu); i++)
			gamemenu[i].label = gettext(gamemenu[i].label);
		for (i = 0; i < ELEMENTS(helpmenu); i++)
			helpmenu[i].label = gettext(helpmenu[i].label);
	}

	window = gnome_app_new ("gnomine", _("GNOME Mines"));
	gnome_app_create_menus (GNOME_APP (window), mainmenu);
	/* FIXME: this should be resizable */
	gtk_window_set_resizable (GTK_WINDOW (window), FALSE);

	appbar = GNOME_APPBAR (gnome_appbar_new (FALSE, TRUE, GNOME_PREFERENCES_NEVER));
	gnome_app_set_statusbar (GNOME_APP (window), GTK_WIDGET (appbar));
	
	g_signal_connect(GTK_OBJECT(window), "delete_event",
			    GTK_SIGNAL_FUNC(quit_game), NULL);
	g_signal_connect(GTK_OBJECT(window), "focus_out_event",
			    GTK_SIGNAL_FUNC(focus_out_cb), NULL);
	g_signal_connect (GTK_OBJECT (window), "configure_event",
			  G_CALLBACK (configure_cb), NULL);

	all_boxes = gtk_vbox_new (FALSE, 0);

	gnome_app_set_contents (GNOME_APP (window), all_boxes);

        	button_table = gtk_table_new (2, 3, FALSE);
	gtk_box_pack_start (GTK_BOX (all_boxes), button_table, TRUE, TRUE, 0);

        	pm_current = NULL;

	mbutton = gtk_button_new ();
	g_signal_connect (GTK_OBJECT (mbutton), "clicked",
			 GTK_SIGNAL_FUNC(new_game), NULL);
        gtk_widget_set_size_request (mbutton, 38, 38);
	gtk_table_attach (GTK_TABLE (button_table), mbutton, 1, 2, 0, 1,
			  0, 0, 5, 5);

	face_box = gtk_vbox_new (FALSE, 0);
	gtk_container_add (GTK_CONTAINER (mbutton), face_box);
	
	pm_win     = image_widget_setup ("gnomine/face-win.xpm");
	pm_sad     = image_widget_setup ("gnomine/face-sad.xpm");
	pm_smile   = image_widget_setup ("gnomine/face-smile.xpm");
	pm_cool    = image_widget_setup ("gnomine/face-cool.xpm");
	pm_worried = image_widget_setup ("gnomine/face-worried.xpm");

        gtk_box_pack_start (GTK_BOX(face_box), pm_win, FALSE, FALSE, 0);
        gtk_box_pack_start (GTK_BOX(face_box), pm_sad, FALSE, FALSE, 0);
        gtk_box_pack_start (GTK_BOX(face_box), pm_smile, FALSE, FALSE, 0);
        gtk_box_pack_start (GTK_BOX(face_box), pm_cool, FALSE, FALSE, 0);
        gtk_box_pack_start (GTK_BOX(face_box), pm_worried, FALSE, FALSE, 0);

	show_face (pm_smile); 

        align = gtk_alignment_new (0.5, 0.5, 0.0, 0.0);
	gtk_table_attach (GTK_TABLE (button_table), align, 1, 2, 1, 2,
			  GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL,
			  0, 0);
  
	box = gtk_vbox_new (FALSE, 0);
	gtk_container_add (GTK_CONTAINER (align), box);
	mfield = gtk_minefield_new ();
	gtk_box_pack_start (GTK_BOX (box), mfield, TRUE, TRUE, 0);

        ralign = gtk_alignment_new (0.5, 0.5, 0.0, 0.0);
	gtk_box_pack_start (GTK_BOX (box), ralign, TRUE, TRUE, 0);
	rbutton = gtk_button_new_with_label ("Press to resume");
	g_signal_connect (GTK_OBJECT (rbutton), "clicked", 
			  GTK_SIGNAL_FUNC (resume_game_cb), NULL);
        gtk_container_add (GTK_CONTAINER (ralign), rbutton);

        setup_mode (mfield, fsize);

	gtk_minefield_set_use_question_marks(GTK_MINEFIELD(mfield),
					     use_question_marks);
	
	g_signal_connect(GTK_OBJECT(mfield), "marks_changed",
			   GTK_SIGNAL_FUNC(marks_changed), NULL);
	g_signal_connect(GTK_OBJECT(mfield), "explode",
			   GTK_SIGNAL_FUNC(lose_game), NULL);
	g_signal_connect(GTK_OBJECT(mfield), "win",
			   GTK_SIGNAL_FUNC(win_game), NULL);
	g_signal_connect(GTK_OBJECT(mfield), "look",
			   GTK_SIGNAL_FUNC(look_cell), NULL);
	g_signal_connect(GTK_OBJECT(mfield), "unlook",
			   GTK_SIGNAL_FUNC(unlook_cell), NULL);
	
	status_box = gtk_hbox_new (FALSE, GNOME_PAD);
	gtk_box_pack_start (GTK_BOX (appbar), status_box, 
			    FALSE, FALSE, 0);

	label = gtk_label_new(_("Flags:"));
	gtk_box_pack_start (GTK_BOX (status_box), label, 
			    FALSE, FALSE, 0);
	
	flabel = gtk_label_new ("0");
	gtk_box_pack_start (GTK_BOX (status_box), flabel, 
			    FALSE, FALSE, 0);

	label = gtk_label_new (_("Time:"));
	gtk_box_pack_start (GTK_BOX (status_box), label, 
			    FALSE, FALSE, 0);

        clk = games_clock_new ();
	gtk_box_pack_start (GTK_BOX (status_box), clk, 
			    FALSE, FALSE, 0);

	update_score_state ();

	new_game (mfield, NULL);

        gtk_widget_show_all (window);
	/* All this hiding is a bit ugly, but it's better than a
	 * ton of gtk_widget_show calls. */
	gtk_widget_hide (ralign);
	gtk_widget_hide (pm_win);
	gtk_widget_hide (pm_sad);
	gtk_widget_hide (pm_cool);
	gtk_widget_hide (pm_worried);
	
        gtk_main ();

	return 0;
}
