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
#include <string.h>

#include "minefield.h"

#include "face-worried.xpm"
#include "face-smile.xpm"
#include "face-cool.xpm"
#include "face-sad.xpm"
#include "face-win.xpm"

static GtkWidget *mfield;
static GtkWidget *pref_dialog;
static GtkWidget *rbutton;
GtkWidget *window;
GtkWidget *flabel;
GtkWidget *xentry;
GtkWidget *yentry;
GtkWidget *mentry;
GtkWidget *sentry;
GtkWidget *mbutton;
GtkWidget *plabel;
GtkWidget *cframe;
GtkWidget *clk;
GtkWidget *pm_win, *pm_sad, *pm_smile, *pm_cool, *pm_worried, *pm_current;
GtkWidget *face_box;
gint ysize=-1, xsize=-1;
gint nmines=-1;
gint fsize=-1, fsc;
gint minesize=-1;

char *fsize2names[] = {
	N_("Tiny"),
	N_("Medium"),
	N_("Biiiig"),
	N_("Custom"),
};

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
	char val[16];

	sprintf(val, "%d/%d", mfield->flags, mfield->mcount);
	gtk_label_set(GTK_LABEL(flabel), val);
}

void
show_scores (gchar *level, guint pos)
{
	gnome_scores_display (_("Gnome Mines"), "gnomine", level, pos);
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
        gtk_clock_stop(GTK_CLOCK(clk));
	gtk_clock_set_seconds(GTK_CLOCK(clk), 0);
        show_face(pm_smile);
	gtk_minefield_restart(GTK_MINEFIELD(mfield));
	gtk_widget_draw(mfield, NULL);
	set_flabel(GTK_MINEFIELD(mfield));

	gtk_widget_hide (rbutton);
	gtk_widget_show (mfield);
}

void focus_out_cb (GtkWidget *widget, GdkEventFocus *event, gpointer data)
{
	if (GTK_CLOCK(clk)->timer_id == -1)
		return;

	gtk_widget_hide (mfield);
	gtk_widget_show (rbutton);
	gtk_clock_stop(GTK_CLOCK(clk)); 
}

void resume_game_cb (GtkWidget *widget, gpointer data)
{
	gtk_widget_hide (rbutton);
	gtk_widget_show (mfield);
	gtk_clock_start(GTK_CLOCK(clk));
}

void marks_changed(GtkWidget *widget, gpointer data)
{
        set_flabel(GTK_MINEFIELD(widget));
	gtk_clock_start(GTK_CLOCK(clk));
}

void lose_game(GtkWidget *widget, gpointer data)
{
        show_face(pm_sad);
        gtk_clock_stop(GTK_CLOCK(clk));
}

void win_game(GtkWidget *widget, gpointer data)
{
        gfloat score;
        int pos;
        gchar buf[64];

        gtk_clock_stop(GTK_CLOCK(clk));
        show_face(pm_win);

	if(fsize<3) {
	    score = (gfloat) (GTK_CLOCK(clk)->stopped / 60) + 
		    (gfloat) (GTK_CLOCK(clk)->stopped % 60) / 100;

            strncpy(buf, fsize2names[fsize], sizeof(buf));
	    pos = gnome_score_log(score, buf, FALSE);

	} else {
	    score = ((nmines * 100) / (xsize * ysize)) /
		    (gfloat) (GTK_CLOCK(clk)->stopped); 

            strncpy(buf, fsize2names[fsize], sizeof(buf));
	    pos = gnome_score_log(score, buf, TRUE);
	}
	show_scores(buf, pos);
}

void look_cell(GtkWidget *widget, gpointer data)
{
        show_face(pm_worried);
        gtk_clock_start(GTK_CLOCK(clk));
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
	minesize = range (minesize, 2, 100);
	xsize    = range (xsize, 4, 100);
	ysize    = range (ysize, 4, 100);
	nmines   = range (nmines, 1, xsize * ysize);
}

void
about(GtkWidget *widget, gpointer data)
{
        static GtkWidget *about;

        const gchar *authors[] = {
		N_("Code: Pista"),
		N_("Faces: tigert"),
		N_("Score: HoraPe"),
		NULL
	};

	if (about) {
		gdk_window_raise (about->window);
		gdk_window_show (about->window);
		return;
	}

#ifdef ENABLE_NLS
       {
            int i=0;
            while (authors[i] != NULL) { authors[i]=_(authors[i]); i++; }
       }
#endif

        about = gnome_about_new (_("Gnome Mines"), VERSION,
				 _("(C) 1997-1999 the Free Software Foundation"),
				 (const char **)authors,
				 _("Minesweeper clone"),
				 NULL);
	gtk_signal_connect (GTK_OBJECT (about), "destroy", GTK_SIGNAL_FUNC
			(gtk_widget_destroyed), &about);
	gnome_dialog_set_parent (GNOME_DIALOG (about), GTK_WINDOW (window));
        gtk_widget_show (about);
}

void size_radio_callback(GtkWidget *widget, gpointer data)
{
	if (GPOINTER_TO_INT (data) == fsc)
		return;

	if (!pref_dialog)
		return;

	fsc = GPOINTER_TO_INT (data);

	gtk_widget_set_sensitive(cframe, fsc == 3);

	gnome_property_box_changed (GNOME_PROPERTY_BOX (pref_dialog));
}

static void help_cb (GtkWidget * widget, gpointer data)
{

  GnomeHelpMenuEntry help_entry = { "gnome-mines", "menubar.html" };

  gnome_help_display (NULL, &help_entry);
}

static void apply_cb (GtkWidget *widget, gint pagenum, gpointer data)
{
        guint oldxsize, oldysize, oldnmines, oldfsize, oldminesize;

	if (pagenum != -1)
		return;
  
	oldxsize = xsize;
	oldysize = ysize;
	oldnmines = nmines;
	oldfsize = fsize;
	oldminesize = minesize;

	xsize  = atoi(gtk_entry_get_text(GTK_ENTRY(xentry)));
	ysize  = atoi(gtk_entry_get_text(GTK_ENTRY(yentry)));
	nmines = atoi(gtk_entry_get_text(GTK_ENTRY(mentry)));
	minesize = gtk_spin_button_get_value_as_int(GTK_SPIN_BUTTON(sentry));
	fsize  = fsc;

	verify_ranges ();
	setup_mode(mfield, fsize);

	if ((oldxsize != xsize) || (oldysize != ysize) || (oldfsize != fsize)
			|| (oldnmines != nmines)) {
		new_game(mfield, NULL);
	}

	gnome_config_set_int("/gnomine/geometry/xsize",  xsize);
	gnome_config_set_int("/gnomine/geometry/ysize",  ysize);
	gnome_config_set_int("/gnomine/geometry/nmines", nmines);
	gnome_config_set_int("/gnomine/geometry/minesize", minesize);
	gnome_config_set_int("/gnomine/geometry/mode",   fsize);
	gnome_config_sync();
}

void prop_box_changed_callback (GtkWidget *widget, gpointer data)
{
	if (!pref_dialog)
		return;

	gnome_property_box_changed (GNOME_PROPERTY_BOX (pref_dialog));
}

void preferences_callback (GtkWidget *widget, gpointer data)
{
	GtkWidget *label;
	GtkWidget *table;
	GtkWidget *frame;
	GtkWidget *vbox;
	GtkWidget *hbox;
	GtkWidget *button;
	GtkWidget *table2;
	GtkWidget *label2;
        GtkObject *adj;
        gchar numstr[8];
	
	if (pref_dialog)
		return;

	label = gtk_label_new (_("Game"));
	gtk_widget_show (label);

	table = gtk_table_new (2, 2, FALSE);
	gtk_container_border_width (GTK_CONTAINER (table), GNOME_PAD);
	gtk_widget_show (table);
	gtk_table_set_row_spacings (GTK_TABLE (table), GNOME_PAD);
	gtk_table_set_col_spacings (GTK_TABLE (table), GNOME_PAD);

	frame = gtk_frame_new (_("Field size"));
	gtk_container_border_width (GTK_CONTAINER (frame), 0);
	gtk_widget_show (frame);

	vbox = gtk_vbox_new (TRUE, 0);
	gtk_container_border_width (GTK_CONTAINER (vbox), GNOME_PAD);
	gtk_widget_show (vbox);

	button = gtk_radio_button_new_with_label(NULL, _("Tiny"));
	if (fsize == 0)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "clicked",
			GTK_SIGNAL_FUNC (size_radio_callback), (gpointer) 0);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
        gtk_widget_show(button);

	button = gtk_radio_button_new_with_label
		(gtk_radio_button_group (GTK_RADIO_BUTTON(button)),
		 _("Medium"));
	if (fsize == 1)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "clicked",
			GTK_SIGNAL_FUNC (size_radio_callback), (gpointer) 1);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
        gtk_widget_show (button);

	button = gtk_radio_button_new_with_label
		(gtk_radio_button_group (GTK_RADIO_BUTTON (button)),
		 _("Biiiig"));
	if (fsize == 2)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "clicked",
			GTK_SIGNAL_FUNC (size_radio_callback), (gpointer) 2);
	gtk_box_pack_start (GTK_BOX (vbox), button, FALSE, FALSE, 0);
        gtk_widget_show(button);
	
	button = gtk_radio_button_new_with_label
		(gtk_radio_button_group(GTK_RADIO_BUTTON(button)),
		 _("Custom"));
	if (fsize == 3)
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (button),
				TRUE);
	gtk_signal_connect (GTK_OBJECT (button), "clicked",
			GTK_SIGNAL_FUNC (size_radio_callback), (gpointer) 3);
	gtk_box_pack_start (GTK_BOX (vbox), button, TRUE, TRUE, 0);
        gtk_widget_show(button);

	gtk_container_add (GTK_CONTAINER (frame), vbox);

	gtk_table_attach (GTK_TABLE (table), frame, 0, 1, 0, 1, GTK_EXPAND |
			GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);

	cframe = gtk_frame_new (_("Custom size"));
	gtk_container_border_width (GTK_CONTAINER (cframe), 0);
	gtk_widget_set_sensitive (cframe, fsize == 3);
	gtk_widget_show (cframe);

	table2 = gtk_table_new (3, 2, FALSE);
	gtk_container_border_width (GTK_CONTAINER (table2), GNOME_PAD);
	gtk_widget_show (table2);
	gtk_table_set_row_spacings (GTK_TABLE (table2), GNOME_PAD);

	label2 = gtk_label_new (_("Horizontal:"));
	gtk_misc_set_alignment (GTK_MISC (label2), 0, 0.5);
	gtk_widget_show (label2);
	gtk_table_attach (GTK_TABLE (table2), label2, 0, 1, 0, 1,
			GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);

	xentry = gtk_entry_new ();
	gtk_widget_set_usize (xentry, 50, -1);
	gtk_table_attach (GTK_TABLE (table2), xentry, 1, 2, 0, 1, 0, GTK_EXPAND
			| GTK_FILL, 0, 0);
	sprintf(numstr, "%d", xsize);
	gtk_entry_set_text(GTK_ENTRY(xentry),numstr);
	gtk_widget_show (xentry);
	gtk_signal_connect (GTK_OBJECT (xentry), "key_press_event",
			GTK_SIGNAL_FUNC (prop_box_changed_callback), NULL);

	label2 = gtk_label_new (_("Vertical:"));
	gtk_misc_set_alignment (GTK_MISC (label2), 0, 0.5);
	gtk_widget_show (label2);
	gtk_table_attach (GTK_TABLE (table2), label2, 0, 1, 1, 2,
			GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);

	yentry = gtk_entry_new ();
	gtk_widget_set_usize (yentry, 50, -1);
	gtk_table_attach (GTK_TABLE (table2), yentry, 1, 2, 1, 2, 0, GTK_EXPAND
			| GTK_FILL, 0, 0);
	sprintf(numstr, "%d", ysize);
	gtk_entry_set_text(GTK_ENTRY(yentry),numstr);
	gtk_widget_show (yentry);
	gtk_signal_connect (GTK_OBJECT (yentry), "key_press_event",
			GTK_SIGNAL_FUNC (prop_box_changed_callback), NULL);

	label2 = gtk_label_new (_("Number of mines:"));
	gtk_misc_set_alignment (GTK_MISC (label2), 0, 0.5);
	gtk_widget_show (label2);
	gtk_table_attach (GTK_TABLE (table2), label2, 0, 1, 2, 3,
			GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);

	mentry = gtk_entry_new ();
	gtk_widget_set_usize (mentry, 50, -1);
	gtk_table_attach (GTK_TABLE (table2), mentry, 1, 2, 2, 3, GTK_FILL, GTK_EXPAND
			| GTK_FILL, 0, 0);
	sprintf(numstr, "%d", nmines);
	gtk_entry_set_text(GTK_ENTRY(mentry),numstr);
	gtk_widget_show (mentry);
	gtk_signal_connect (GTK_OBJECT (mentry), "key_press_event",
			GTK_SIGNAL_FUNC (prop_box_changed_callback), NULL);

	gtk_container_add (GTK_CONTAINER (cframe), table2);

	gtk_table_attach (GTK_TABLE (table), cframe, 1, 2, 0, 1, GTK_EXPAND |
			GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);

	hbox = gtk_hbox_new (FALSE, GNOME_PAD);
	gtk_widget_show (hbox);

	label2 = gtk_label_new(_("Mine size:"));
	gtk_box_pack_start (GTK_BOX (hbox), label2, FALSE, FALSE, 0);
	gtk_widget_show (label2);

        adj = gtk_adjustment_new(minesize, 2, 99, 1, 5, 10);
	sentry = gtk_spin_button_new(GTK_ADJUSTMENT(adj), 10, 0);
        gtk_spin_button_set_update_policy(GTK_SPIN_BUTTON(sentry),
					  GTK_UPDATE_ALWAYS
#ifndef HAVE_GTK_SPIN_BUTTON_SET_SNAP_TO_TICKS
					  | GTK_UPDATE_SNAP_TO_TICKS
#endif
					  );
#ifdef HAVE_GTK_SPIN_BUTTON_SET_SNAP_TO_TICKS
	gtk_spin_button_set_snap_to_ticks(GTK_SPIN_BUTTON(sentry), 1);
#endif
	gtk_signal_connect (GTK_OBJECT (adj), "value_changed", GTK_SIGNAL_FUNC
			(prop_box_changed_callback), NULL);
	gtk_box_pack_start (GTK_BOX (hbox), sentry, TRUE, TRUE, 0);
	gtk_widget_show(sentry);

	gtk_table_attach (GTK_TABLE (table), hbox, 0, 1, 1, 2, GTK_EXPAND |
			GTK_FILL, 0, 0, 0);

	pref_dialog = gnome_property_box_new ();
	gnome_dialog_set_parent (GNOME_DIALOG (pref_dialog),
			GTK_WINDOW (window));
	gtk_window_set_title (GTK_WINDOW (pref_dialog),
			_("Gnome Mine Preferences"));
	gtk_signal_connect (GTK_OBJECT (pref_dialog), "destroy",
			GTK_SIGNAL_FUNC (gtk_widget_destroyed), &pref_dialog);

	gnome_property_box_append_page (GNOME_PROPERTY_BOX (pref_dialog),
			table, label);

	gtk_signal_connect (GTK_OBJECT (pref_dialog), "apply", GTK_SIGNAL_FUNC
			(apply_cb), NULL);

	gtk_signal_connect (GTK_OBJECT (pref_dialog), "help", GTK_SIGNAL_FUNC
			(help_cb), NULL);

        fsc = fsize;

	gtk_widget_show (pref_dialog);
}

GnomeUIInfo gamemenu[] = {
        GNOMEUIINFO_MENU_NEW_GAME_ITEM(new_game, NULL),
	GNOMEUIINFO_SEPARATOR,
	GNOMEUIINFO_MENU_SCORES_ITEM(top_ten, NULL),
	GNOMEUIINFO_SEPARATOR,
	GNOMEUIINFO_MENU_EXIT_ITEM(quit_game, NULL),
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
	char buf[20];
	sprintf (buf, "%d", n);
	return strdup (buf);
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



static int xpos=-1, ypos=-1;

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
	GtkWidget *status_table;
	GtkWidget *button_table;
        GtkWidget *align;
        GtkWidget *label;
	GtkWidget *box;
	GnomeClient *client;

	gnome_score_init("gnomine");

	bindtextdomain (PACKAGE, GNOMELOCALEDIR);
	textdomain (PACKAGE);

        gnome_init_with_popt_table("gnomine", VERSION, argc, argv,
				   options, 0, NULL);

	gnome_window_icon_set_default_from_file (GNOME_ICONDIR"/gnome-gnomine.png");
	client = gnome_master_client ();
	gtk_signal_connect (GTK_OBJECT (client), "save_yourself",
			    GTK_SIGNAL_FUNC (save_state), argv[0]);

	if (xpos > 0 || ypos > 0)
	  gtk_widget_set_uposition (window, xpos, ypos);
		
	if (xsize == -1)
	  xsize  = gnome_config_get_int("/gnomine/geometry/xsize=16");
	if (ysize == -1)
	  ysize = gnome_config_get_int("/gnomine/geometry/ysize=16");
	if (nmines == -1)
	  nmines = gnome_config_get_int("/gnomine/geometry/nmines=40");
	if (minesize == -1){
	  minesize = gnome_config_get_int("/gnomine/geometry/minesize=17");
	  /* XXX is this necessary, verify_ranges() is just below. */
	  if (minesize < 0)
	    minesize = 1;
	}
	if (fsize == -1)
	  fsize  = gnome_config_get_int("/gnomine/geometry/mode=0");

	verify_ranges ();
        gdk_imlib_init ();

#ifdef ENABLE_NLS 
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
#endif /* ENABLE_NLS */

        window = gnome_app_new("gnomine", _("Gnome Mines"));
	gnome_app_create_menus(GNOME_APP(window), mainmenu);

	appbar = GNOME_APPBAR (gnome_appbar_new(FALSE, FALSE, FALSE));
	gnome_app_set_statusbar(GNOME_APP (window), GTK_WIDGET (appbar));
	
        gtk_signal_connect(GTK_OBJECT(window), "delete_event",
                           GTK_SIGNAL_FUNC(quit_game), NULL);
	gtk_signal_connect(GTK_OBJECT(window), "focus_out_event",
			    GTK_SIGNAL_FUNC(focus_out_cb), NULL);

        all_boxes = gtk_vbox_new(FALSE, 0);

	gnome_app_set_contents(GNOME_APP(window), all_boxes);

        button_table = gtk_table_new(2, 3, FALSE);
	gtk_box_pack_start(GTK_BOX(all_boxes), button_table, TRUE, TRUE, 0);

        pm_current = NULL;

	mbutton = gtk_button_new();
	gtk_signal_connect(GTK_OBJECT(mbutton), "clicked",
                           GTK_SIGNAL_FUNC(new_game), NULL);
        gtk_widget_set_usize(mbutton, 38, 38);
	gtk_table_attach(GTK_TABLE(button_table), mbutton, 1, 2, 0, 1,
			 0, 0, 5, 5);

	face_box = gtk_vbox_new(FALSE, 0);
	gtk_container_add(GTK_CONTAINER(mbutton), face_box);
	
	pm_win     = gnome_pixmap_new_from_xpm_d (face_win_xpm);
	pm_sad     = gnome_pixmap_new_from_xpm_d (face_sad_xpm);
	pm_smile   = gnome_pixmap_new_from_xpm_d (face_smile_xpm);
	pm_cool    = gnome_pixmap_new_from_xpm_d (face_cool_xpm);
	pm_worried = gnome_pixmap_new_from_xpm_d (face_worried_xpm);

        gtk_box_pack_start(GTK_BOX(face_box), pm_win, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(face_box), pm_sad, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(face_box), pm_smile, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(face_box), pm_cool, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(face_box), pm_worried, FALSE, FALSE, 0);

	show_face(pm_smile);

	gtk_widget_show(face_box);
	gtk_widget_show(mbutton);

	gtk_widget_show(button_table);
	
        align = gtk_alignment_new (0.5, 0.5, 0.0, 0.0);
	gtk_table_attach (GTK_TABLE (button_table), align, 1, 2, 1, 2,
			  GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL,
			  0, 0);
        gtk_widget_show (align);
  
	gtk_widget_push_visual (gdk_imlib_get_visual ());
	gtk_widget_push_colormap (gdk_imlib_get_colormap ());
	gtk_widget_pop_colormap ();
	gtk_widget_pop_visual ();

	box = gtk_vbox_new(FALSE, 0);
	gtk_container_add (GTK_CONTAINER (align), box);
	mfield = gtk_minefield_new();
	gtk_box_pack_start(GTK_BOX(box), mfield, FALSE, FALSE, 0);

	rbutton = gtk_button_new_with_label ("Press to resume");
	gtk_signal_connect (GTK_OBJECT(rbutton), "released", resume_game_cb, NULL);
	gtk_box_pack_start(GTK_BOX(box), rbutton, TRUE, FALSE, 0);
	gtk_widget_show (box);

        setup_mode(mfield, fsize);
	
	gtk_signal_connect(GTK_OBJECT(mfield), "marks_changed",
			   GTK_SIGNAL_FUNC(marks_changed), NULL);
	gtk_signal_connect(GTK_OBJECT(mfield), "explode",
			   GTK_SIGNAL_FUNC(lose_game), NULL);
	gtk_signal_connect(GTK_OBJECT(mfield), "win",
			   GTK_SIGNAL_FUNC(win_game), NULL);
	gtk_signal_connect(GTK_OBJECT(mfield), "look",
			   GTK_SIGNAL_FUNC(look_cell), NULL);
	gtk_signal_connect(GTK_OBJECT(mfield), "unlook",
			   GTK_SIGNAL_FUNC(unlook_cell), NULL);
	
	gtk_widget_show(mfield);

        status_table = gtk_table_new(1, 4, TRUE);
	gtk_box_pack_start(GTK_BOX(all_boxes), status_table, TRUE, TRUE, 0);
	label = gtk_label_new(_("Flags:"));
	gtk_table_attach(GTK_TABLE(status_table), label,
			 0, 1, 0, 1, 0, 0, 3, 3);
	gtk_widget_show(label);
	
	flabel = gtk_label_new("0");
	
	gtk_table_attach(GTK_TABLE(status_table), flabel,
			 1, 2, 0, 1, 0, 0, 3, 3);
	gtk_widget_show(flabel);

	label = gtk_label_new(_("Time:"));
	gtk_table_attach(GTK_TABLE(status_table), label,
			 2, 3, 0, 1, 0, 0, 3, 3);
	gtk_widget_show(label);

        clk = gtk_clock_new(GTK_CLOCK_INCREASING);
	gtk_table_attach(GTK_TABLE(status_table), clk,
		3, 4, 0, 1, 0, 0, 3 ,3);
	gtk_widget_show(clk);
	
        gtk_widget_show(status_table);
	
	gtk_widget_show(all_boxes);

	new_game(mfield, NULL);

        /* gtk_window_set_policy(GTK_WINDOW(window), FALSE, FALSE, TRUE); */

        gtk_widget_show(window);

        gtk_main();

	return 0;
}
