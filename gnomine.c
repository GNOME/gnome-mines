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
#include <gnome.h>
#include <libgnomeui/gnome-window-icon.h>
#include <gconf/gconf-client.h>
#include <string.h>

#include "minefield.h"
#include "games-clock.h"
#include "games-frame.h"

/* Limits for various minefield properties */
#define XSIZE_MIN 4
#define XSIZE_MAX 100
#define YSIZE_MIN 4
#define YSIZE_MAX 100
#define WIDTH_DEFAULT  300
#define HEIGHT_DEFAULT 300

/* GConf key paths */
#define KEY_DIR "/apps/gnomine"
#define KEY_XSIZE "/apps/gnomine/geometry/xsize"
#define KEY_YSIZE "/apps/gnomine/geometry/ysize"
#define KEY_NMINES "/apps/gnomine/geometry/nmines"
#define KEY_MODE "/apps/gnomine/geometry/mode"
#define KEY_USE_QUESTION_MARKS "/apps/gnomine/use_question_marks"
#define KEY_WIDTH    	       "/apps/gnomine/geometry/width"
#define KEY_HEIGHT   	       "/apps/gnomine/geometry/height"

static GtkWidget *mf_frame;
static GtkWidget *mfield;
static GtkWidget *pref_dialog = NULL;
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

/* It's a little ugly, but it stops the hint dialogs triggering the
 * hide-the-window-to-stop cheating thing. */
gboolean disable_hiding = FALSE;

static void create_preferences (void);


static GtkWidget *
image_widget_setup (char *name)
{
	GdkPixbuf *pixbuf = NULL;
	char *filename = NULL;

	filename = gnome_program_locate_file (NULL,
					      GNOME_FILE_DOMAIN_APP_PIXMAP, name,
					      TRUE, NULL);
	if (filename != NULL)
		pixbuf = gdk_pixbuf_new_from_file (filename, NULL);

	g_free (filename);

	return gtk_image_new_from_pixbuf (pixbuf);
}

static void
show_face (GtkWidget *pm)
{
        if (pm_current == pm) return;

	if (pm_current) {
		gtk_widget_hide (pm_current); 
	}

	gtk_widget_show (pm);
	
	pm_current = pm;
}

static void
quit_game (GtkWidget *widget, gpointer data)
{
	gint width, height;

	gtk_window_get_size (GTK_WINDOW (window), &width, &height);
	gconf_client_set_int (conf_client, KEY_WIDTH,  width, NULL);
	gconf_client_set_int (conf_client, KEY_HEIGHT, height, NULL);

	gtk_main_quit ();
}

static void
set_flabel (GtkMineField *mfield)
{
	char *val;

	val = g_strdup_printf ("%d/%d", mfield->flag_count, mfield->mcount);
	gtk_label_set_text (GTK_LABEL (flabel), val);
	g_free (val);
}

static void
update_score_state (void)
{
        gchar **names = NULL;
        gfloat *scores = NULL;
	time_t *scoretimes = NULL;
	gint top;
	gchar buf[64];

	if (fsize<4)
		strncpy (buf, fsize2names[fsize], sizeof(buf));

	top = gnome_score_get_notable ("gnomine", buf, &names, &scores, &scoretimes);
	if (top > 0) {
		gtk_widget_set_sensitive (gamemenu[2].widget, TRUE);
		g_strfreev (names);
		g_free (scores);
		g_free (scoretimes);
	} else { 
		gtk_widget_set_sensitive (gamemenu[2].widget, FALSE);
	}
}

static void
show_scores (gchar *level, guint pos)
{
	gnome_scores_display (_("GNOME Mines"), "gnomine", level, pos);
}

static void
top_ten (GtkWidget *widget, gpointer data)
{
	gchar buf[64];

	if(fsize<4)
		strncpy (buf, fsize2names[fsize], sizeof(buf));

	show_scores (buf, 0);
}

static void
new_game (GtkWidget *widget, gpointer data)
{
	gint width, height, w_diff, h_diff;
	guint size;
	gint x, y;
	static gint size_table[3][3] = {{ 8, 8, 10 }, {16, 16, 40}, {30, 16, 99}};
	GtkMineField *mf = GTK_MINEFIELD (mfield);

	games_clock_stop (GAMES_CLOCK (clk));
	games_clock_set_seconds (GAMES_CLOCK (clk), 0);
	show_face (pm_smile);

	/* get window size and mine square size (gtk_minefield_restart() may change it) */
	gtk_window_get_size (GTK_WINDOW (window), &width, &height);
	size = mf->minesize;
	w_diff = width  - mfield->allocation.width;
	h_diff = height - mfield->allocation.height;

	if (fsize == 3) {
		x = xsize;
		y = ysize;
		mf->mcount = nmines;
	} else {
		x = size_table[fsize][0];
		y = size_table[fsize][1];
		mf->mcount = size_table[fsize][2];
	}
	gtk_minefield_set_size (GTK_MINEFIELD (mfield), x, y);
	gtk_minefield_restart (GTK_MINEFIELD (mfield));

	set_flabel (GTK_MINEFIELD (mfield));

	gtk_widget_hide (ralign);
	gtk_widget_show (mf_frame); 
}

static void
hint (GtkWidget *widget, gpointer data)
{
	int result;
	gchar * message;
	GtkWidget * dialog;
	
	result = gtk_minefield_hint (GTK_MINEFIELD (mfield));

	if (result == MINEFIELD_HINT_ACCEPTED) {
		/* There is a ten second penalty for accepting a hint. */
		games_clock_add_seconds (GAMES_CLOCK (clk), 10);
		return;
	}

	if (result == MINEFIELD_HINT_NO_GAME)
		message = _("Click a square, any square");
	else
		message = _("Maybe they're all mines ...");

	dialog = gtk_message_dialog_new (GTK_WINDOW (window), GTK_DIALOG_MODAL,
					 GTK_MESSAGE_INFO, GTK_BUTTONS_OK,
					 message, NULL);
	gtk_window_set_resizable (GTK_WINDOW (dialog), FALSE);
	gtk_label_set_use_markup (GTK_LABEL (GTK_MESSAGE_DIALOG (dialog)->label), TRUE);

	disable_hiding = TRUE;
	gtk_dialog_run (GTK_DIALOG (dialog));
	gtk_widget_destroy (dialog);
	disable_hiding = FALSE;

}

static void
focus_out_cb (GtkWidget *widget, GdkEventFocus *event, gpointer data)
{
	if ((GAMES_CLOCK (clk)->timer_id != -1) 
	    && (!disable_hiding)) {
		gtk_widget_hide (mf_frame);
		gtk_widget_show (ralign);
		gtk_widget_grab_focus (rbutton);

		games_clock_stop (GAMES_CLOCK (clk)); 
	}
}

static void
resume_game_cb (GtkButton *widget, gpointer data)
{
	gtk_widget_hide (ralign);
	gtk_widget_show (mf_frame);

	games_clock_start (GAMES_CLOCK (clk));
}

static void
marks_changed (GtkWidget *widget, gpointer data)
{
        set_flabel (GTK_MINEFIELD (widget));

	games_clock_start (GAMES_CLOCK (clk));
}

static void
lose_game (GtkWidget *widget, gpointer data)
{
        show_face (pm_sad);

	gtk_widget_grab_focus (mbutton);

        games_clock_stop (GAMES_CLOCK (clk));
}

static void
win_game (GtkWidget *widget, gpointer data)
{
        gfloat score;
        int pos;
        gchar buf[64];


        games_clock_stop (GAMES_CLOCK (clk));

	gtk_widget_grab_focus (mbutton);

        show_face (pm_win);

	if(fsize<4) {
	    score = (gfloat) (GAMES_CLOCK (clk)->stopped / 60) + 
		    (gfloat) (GAMES_CLOCK (clk)->stopped % 60) / 100;

            strncpy(buf, fsize2names[fsize], sizeof(buf));
	    pos = gnome_score_log (score, buf, FALSE);
	} else {
	    score = ((nmines * 100) / (xsize * ysize)) /
		    (gfloat) (GAMES_CLOCK (clk)->stopped); 

            strncpy(buf, fsize2names[fsize], sizeof(buf));
	    pos = gnome_score_log (score, buf, TRUE);
	}

	update_score_state ();

	show_scores (buf, pos);
}

static void
look_cell (GtkWidget *widget, gpointer data)
{
        show_face (pm_worried);

        games_clock_start (GAMES_CLOCK (clk));
}

static void
unlook_cell (GtkWidget *widget, gpointer data)
{
	show_face(pm_cool);
}

static int
range (int val, int min, int max)
{
	if (val < min)
		val = min;
	if (val > max)
		val = max;
	return val;
}


static void
verify_ranges (void)
{
	xsize    = range (xsize, XSIZE_MIN, XSIZE_MAX);
	ysize    = range (ysize, YSIZE_MIN, YSIZE_MAX);
	nmines   = range (nmines, 1, xsize * ysize);
	fsize    = range (fsize,  0, 3);
}

static void
about (GtkWidget *widget, gpointer data)
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
		g_object_unref (pixbuf);
	
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
			new_game (mfield, NULL);
		}
	}
	if (strcmp (key, KEY_YSIZE) == 0) {
		int i;
		i = value ? gconf_value_get_int (value) : 16;
		if (i != ysize) {
			ysize = range (i, YSIZE_MIN, YSIZE_MAX);
			new_game (mfield, NULL);
		}
	}
	if (strcmp (key, KEY_NMINES) == 0) {
		int i;
		i = value ? gconf_value_get_int (value) : 40;
		if (nmines != i) {
			nmines = range (i, 1, xsize * ysize - 2);
			new_game (mfield, NULL);
		}
	}
	if (strcmp (key, KEY_MODE) == 0) {
		int i;
		i = value ? gconf_value_get_int (value) : 0;
		if (i != fsize) {
			fsize = range (i, 0, 3);
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
size_radio_callback (GtkWidget *widget, gpointer data)
{
	int fsc;
	if (!pref_dialog)
		return;

	fsc = GPOINTER_TO_INT (data);

	gconf_client_set_int (conf_client, KEY_MODE,
			      fsc, NULL);

	gtk_widget_set_sensitive(cframe, fsc == 3);
}

static void
fix_nmines (int xsize, int ysize)
{
	int maxmines;

	/* Fix up the maximum number of mines so that there is always at least two
	 * free spaces. It could in theory be left at one, but that gives an
	 * instant win situation. */
	maxmines = xsize*ysize - 2;
	if (nmines > maxmines) {
		gconf_client_set_int (conf_client, KEY_NMINES, maxmines, NULL);
		gtk_spin_button_set_value (GTK_SPIN_BUTTON (mentry), maxmines);
	}
	gtk_spin_button_set_range (GTK_SPIN_BUTTON (mentry), 1, maxmines);
}

static void
xsize_spin_cb (GtkSpinButton *spin, gpointer data)
{
	int size = gtk_spin_button_get_value_as_int (spin);
	gconf_client_set_int (conf_client, KEY_XSIZE,
			      size, NULL);
        fix_nmines (size,ysize);
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
use_question_toggle_cb (GtkCheckButton *check, gpointer data)
{
	gboolean use_marks = gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (check));
	gconf_client_set_bool (conf_client, KEY_USE_QUESTION_MARKS,
				use_marks, NULL);
}

static void
create_preferences (void)
{
	GtkWidget *table;
	GtkWidget *frame;
	GtkWidget *vbox;
	GtkWidget *button;
	GtkWidget *table2;
	GtkWidget *label2;
        
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

	g_signal_connect (G_OBJECT (pref_dialog), "destroy",
			  G_CALLBACK (gtk_widget_destroyed), &pref_dialog);
	g_signal_connect (G_OBJECT (pref_dialog), "response",
			  G_CALLBACK (gtk_widget_hide), NULL);

	/* show all child widgets, but do not display the dialog (yet) */
	gtk_widget_show_all (GTK_WIDGET (table));
}

static void
preferences_callback (GtkWidget *widget, gpointer data)
{
	if (pref_dialog == NULL)
		create_preferences ();
	gtk_window_present (GTK_WINDOW (pref_dialog));
}

GnomeUIInfo gamemenu[] = {
        GNOMEUIINFO_MENU_NEW_GAME_ITEM(new_game, NULL),
	GNOMEUIINFO_MENU_HINT_ITEM(hint, NULL),
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
	argv[i++] = g_strdup_printf ("%d", xsize);
	argv[i++] = "-y";
	argv[i++] = g_strdup_printf ("%d", ysize);
	argv[i++] = "-n";
	argv[i++] = g_strdup_printf ("%d", nmines);
	argv[i++] = "-f";
	argv[i++] = g_strdup_printf ("%d", fsize);
	argv[i++] = "-a";
	argv[i++] = g_strdup_printf ("%d", xpos);
	argv[i++] = "-b";
	argv[i++] = g_strdup_printf ("%d", ypos);

	gnome_client_set_restart_command (client, i, argv);
	/* i.e. clone_command = restart_command - '--sm-client-id' */
	gnome_client_set_clone_command (client, 0, NULL);

	for (j = 2; j < i; j += 2)
		g_free (argv[j]);

	return TRUE;
}



static int xpos = -1, ypos = -1;

static struct poptOption options[] = {
  {NULL, 'x', POPT_ARG_INT, &xsize, 0, N_("Width of grid"), N_("X")},
  {NULL, 'y', POPT_ARG_INT, &ysize, 0, N_("Height of grid"), N_("Y")},
  {NULL, 'n', POPT_ARG_INT, &nmines, 0, N_("Number of mines"), N_("NUMBER")},
  {NULL, 'f', POPT_ARG_INT, &fsize, 0, N_("Size of the board (1=small, 3=large)"), NULL},
  {NULL, 'a', POPT_ARG_INT, &xpos, 0, N_("X location of window"), N_("X")},
  {NULL, 'b', POPT_ARG_INT, &ypos, 0, N_("Y location of window"), N_("Y")},
  {NULL, '\0', 0, NULL, 0}
};

int
main (int argc, char *argv[])
{
        GtkWidget *all_boxes;
	GtkWidget *status_box;
	GtkWidget *button_table;
        GtkWidget *box;        
        GtkWidget *label;
	GnomeClient *client;
	gint width, height;

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
	g_signal_connect (G_OBJECT (client), "save_yourself",
			  G_CALLBACK (save_state), argv[0]);

	if (xpos > 0 || ypos > 0)
	  gdk_window_move (GTK_WIDGET (window)->window, xpos, ypos);
		
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
	if (fsize == -1)
		fsize = gconf_client_get_int (conf_client,
					      KEY_MODE,
					      NULL);
	use_question_marks = gconf_client_get_bool (conf_client, 
						    KEY_USE_QUESTION_MARKS,
						    NULL);
	width = gconf_client_get_int (conf_client, KEY_WIDTH, NULL);
	width = width ? width : WIDTH_DEFAULT;
	height = gconf_client_get_int (conf_client, KEY_HEIGHT, NULL);
	height = height ? height : HEIGHT_DEFAULT;
	
	verify_ranges ();

	window = gnome_app_new ("gnomine", _("GNOME Mines"));
	gnome_app_create_menus (GNOME_APP (window), mainmenu);
	gtk_window_set_default_size (GTK_WINDOW (window), width, height);	
	gtk_window_set_resizable (GTK_WINDOW (window), TRUE);

	g_signal_connect(G_OBJECT (window), "delete_event",
			 G_CALLBACK (quit_game), NULL);
	g_signal_connect(G_OBJECT (window), "focus_out_event",
			 G_CALLBACK (focus_out_cb), NULL);

	all_boxes = gtk_vbox_new (FALSE, 0);

	gnome_app_set_contents (GNOME_APP (window), all_boxes);

	button_table = gtk_table_new (2, 3, FALSE);
	gtk_box_pack_start (GTK_BOX (all_boxes), button_table, TRUE, TRUE, 0);

	pm_current = NULL;

	mbutton = gtk_button_new ();
	g_signal_connect (G_OBJECT (mbutton), "clicked",
			  G_CALLBACK (new_game), NULL);
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

        gtk_box_pack_start (GTK_BOX (face_box), pm_win, FALSE, FALSE, 0);
        gtk_box_pack_start (GTK_BOX (face_box), pm_sad, FALSE, FALSE, 0);
        gtk_box_pack_start (GTK_BOX (face_box), pm_smile, FALSE, FALSE, 0);
        gtk_box_pack_start (GTK_BOX (face_box), pm_cool, FALSE, FALSE, 0);
        gtk_box_pack_start (GTK_BOX (face_box), pm_worried, FALSE, FALSE, 0);

	show_face (pm_smile); 

	box = gtk_vbox_new (FALSE, 0);
	gtk_table_attach_defaults (GTK_TABLE (button_table), box, 1, 2, 1, 2);

	gtk_box_pack_start (GTK_BOX (box), gtk_hseparator_new (), FALSE, FALSE,
			    0);

	mfield = gtk_minefield_new ();

	/* It doesn't really matter what this widget is as long as it's a
	 * container. */
	mf_frame = gtk_alignment_new (0.5, 0.5, 1.0, 1.0);
	gtk_container_add (GTK_CONTAINER (mf_frame), mfield);

	gtk_box_pack_start (GTK_BOX (box), mf_frame, TRUE, TRUE, 0);

	ralign = gtk_alignment_new (0.5, 0.5, 0.0, 0.0);
	gtk_box_pack_start (GTK_BOX (box), ralign, TRUE, TRUE, 0);

	rbutton = gtk_button_new_with_label ("Press to resume");
	g_signal_connect (G_OBJECT (rbutton), "clicked", 
			  G_CALLBACK (resume_game_cb), NULL);
        gtk_container_add (GTK_CONTAINER (ralign), rbutton);

	gtk_minefield_set_use_question_marks (GTK_MINEFIELD (mfield),
					      use_question_marks);
	
	g_signal_connect (G_OBJECT (mfield), "marks_changed",
			  G_CALLBACK (marks_changed), NULL);
	g_signal_connect (G_OBJECT (mfield), "explode",
			  G_CALLBACK (lose_game), NULL);
	g_signal_connect (G_OBJECT (mfield), "win",
			  G_CALLBACK (win_game), NULL);
	g_signal_connect (G_OBJECT (mfield), "look",
			  G_CALLBACK (look_cell), NULL);
	g_signal_connect (G_OBJECT (mfield), "unlook",
			  G_CALLBACK (unlook_cell), NULL);

	gtk_box_pack_start (GTK_BOX (box), gtk_hseparator_new (), FALSE, FALSE,
			    0);
	
	status_box = gtk_hbox_new (TRUE, 0); 
	gtk_box_pack_start (GTK_BOX (box), status_box, 
			    FALSE, FALSE, GNOME_PAD);

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
