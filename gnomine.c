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
#include <string.h>

#include "minefield.h"

#include "face-worried.xpm"
#include "face-smile.xpm"
#include "face-cool.xpm"
#include "face-sad.xpm"
#include "face-win.xpm"

static GtkWidget *mfield;
GtkWidget *window;
GtkWidget *flabel;
GtkWidget *setupdialog;
GtkWidget *mfieldbox;
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
guint ysize, xsize;
guint nmines;
guint fsize, fsc;
guint minesize;

char *fsize2names[] = {
	N_("Tiny"),
	N_("Medium"),
	N_("Biiiig"),
};

void show_face(GtkWidget *pm)
{
        if (pm_current == pm) return;

	if (pm_current) {
                gtk_container_block_resize(GTK_CONTAINER(face_box));
		gtk_widget_hide(pm_current);
	}

	gtk_widget_show(pm);

	if(pm_current) {
		gtk_container_unblock_resize(GTK_CONTAINER(face_box));
	}
	
	pm_current = pm;
}

void quit_game(GtkWidget *widget, gpointer data)
{
        gtk_widget_destroy(window);
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
	gnome_scores_display (_("Gnome mines"), "gnomine", level, pos);
}

void top_ten(GtkWidget *widget, gpointer data)
{
	gchar buf[64];

	if(fsize<3)
		strncpy(buf, fsize2names[fsize], sizeof(buf));
	else
		g_snprintf(buf, sizeof(buf), "%dx%dx%d",xsize,ysize,nmines);

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
        gtk_clock_start(GTK_CLOCK(clk));
}

void setupdialog_destroy(GtkWidget *widget, gint mode)
{
	if (mode == 1) {
		gtk_widget_destroy(setupdialog);
	}
	setupdialog = NULL;
}

void marks_changed(GtkWidget *widget, gpointer data)
{
        set_flabel(GTK_MINEFIELD(widget));
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

        show_face(pm_win);
        gtk_clock_stop(GTK_CLOCK(clk));

	score = (gfloat) (GTK_CLOCK(clk)->stopped / 60) + 
		(gfloat) (GTK_CLOCK(clk)->stopped % 60) / 100; 

	if(fsize<3)
		strncpy(buf, fsize2names[fsize], sizeof(buf));
	else
		g_snprintf(buf, sizeof(buf), "%dx%dx%d",xsize,ysize,nmines);

	pos = gnome_score_log(score, buf, FALSE);
	show_scores(buf, pos);
}

void look_cell(GtkWidget *widget, gpointer data)
{
        show_face(pm_worried);
}

void unlook_cell(GtkWidget *widget, gpointer data)
{
	show_face(pm_cool);
}

void setup_mode(GtkWidget *widget, gint mode)
{
	gint size_table[3][3] = {{ 10, 10, 10 }, {20, 20, 50}, {35, 35, 170}};
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

void do_setup(GtkWidget *widget, gpointer data)
{

	xsize  = atoi(gtk_entry_get_text(GTK_ENTRY(xentry)));
	ysize  = atoi(gtk_entry_get_text(GTK_ENTRY(yentry)));
        nmines = atoi(gtk_entry_get_text(GTK_ENTRY(mentry)));
        minesize = atoi(gtk_entry_get_text(GTK_ENTRY(sentry)));
	fsize  = fsc;
	
        setup_mode(mfield, fsize);
	new_game(mfield, NULL);

	setupdialog_destroy(setupdialog, 1);

	gnome_config_set_int("/gnomine/geometry/xsize",  xsize);
	gnome_config_set_int("/gnomine/geometry/ysize",  ysize);
	gnome_config_set_int("/gnomine/geometry/nmines", nmines);
	gnome_config_set_int("/gnomine/geometry/minesize", minesize);
	gnome_config_set_int("/gnomine/geometry/mode",   fsize);
	gnome_config_sync();
}

void
about(GtkWidget *widget, gpointer data)
{
        GtkWidget *about;
        gchar *authors[] = {
		"Code: Pista",
		"Faces: tigert",
		"Score: HoraPe",
		NULL
	};

        about = gnome_about_new (_("Gnome Mines"), VERSION,
				 "(C) 1997-1998 the Free Software Fundation",
				 authors,
				 _("Minesweeper clone"),
				 NULL);
        gtk_widget_show (about);
}

void size_radio_callback(GtkWidget *widget, gpointer data)
{
	fsc = (gint)data;

	gtk_widget_set_sensitive(cframe, fsc == 3);
}

void setup_game(GtkWidget *widget, gpointer data)
{
        GtkWidget *all_boxes;
	GtkWidget *box, *box2;
        GtkWidget *label;
	GtkWidget *button;
	GtkWidget *frame;
	gchar numstr[8];
	
        if (setupdialog) return;

	setupdialog = gtk_window_new(GTK_WINDOW_DIALOG);

	gtk_container_border_width(GTK_CONTAINER(setupdialog), 10);
	GTK_WINDOW(setupdialog)->position = GTK_WIN_POS_MOUSE;
	gtk_window_set_title(GTK_WINDOW(setupdialog), _("Gnome mines setup"));
	gtk_signal_connect(GTK_OBJECT(setupdialog),
			   "delete_event",
			   GTK_SIGNAL_FUNC(setupdialog_destroy),
			   0);

	all_boxes = gtk_vbox_new(FALSE, 5);
	gtk_container_add(GTK_CONTAINER(setupdialog), all_boxes);

        cframe = gtk_frame_new(_("Custom size"));

	frame = gtk_frame_new(_("Field size"));
	gtk_box_pack_start(GTK_BOX(all_boxes), frame, TRUE, TRUE, 0);
	
	box = gtk_vbox_new(FALSE, 0);
	gtk_container_add(GTK_CONTAINER(frame), box);
	
	button = gtk_radio_button_new_with_label(NULL, _("Tiny"));
	if (fsize == 0) gtk_toggle_button_set_state(GTK_TOGGLE_BUTTON (button), TRUE);
	gtk_signal_connect(GTK_OBJECT(button), "clicked", GTK_SIGNAL_FUNC(size_radio_callback),
			   (gpointer) 0);
	gtk_box_pack_start(GTK_BOX(box), button, TRUE, TRUE, 0);
        gtk_widget_show(button);

	button = gtk_radio_button_new_with_label(gtk_radio_button_group(GTK_RADIO_BUTTON(button)),
						 _("Medium"));
	if (fsize == 1) gtk_toggle_button_set_state(GTK_TOGGLE_BUTTON (button), TRUE);
	gtk_signal_connect(GTK_OBJECT(button), "clicked", GTK_SIGNAL_FUNC(size_radio_callback),
			   (gpointer) 1);
	gtk_box_pack_start(GTK_BOX(box), button, TRUE, TRUE, 0);
        gtk_widget_show(button);

	button = gtk_radio_button_new_with_label(gtk_radio_button_group(GTK_RADIO_BUTTON(button)),
						 _("Biiiig"));
	if (fsize == 2) gtk_toggle_button_set_state(GTK_TOGGLE_BUTTON (button), TRUE);
	gtk_signal_connect(GTK_OBJECT(button), "clicked", GTK_SIGNAL_FUNC(size_radio_callback),
			   (gpointer) 2);
	gtk_box_pack_start(GTK_BOX(box), button, TRUE, TRUE, 0);
        gtk_widget_show(button);
	
	button = gtk_radio_button_new_with_label(gtk_radio_button_group(GTK_RADIO_BUTTON(button)),
						 _("Custom"));
	if (fsize == 3) gtk_toggle_button_set_state(GTK_TOGGLE_BUTTON (button), TRUE);
	gtk_signal_connect(GTK_OBJECT(button), "clicked", GTK_SIGNAL_FUNC(size_radio_callback),
			   (gpointer) 3);
	gtk_box_pack_start(GTK_BOX(box), button, TRUE, TRUE, 0);
        gtk_widget_show(button);

	gtk_widget_show(box);
	gtk_widget_show(frame);

	box2 = gtk_hbox_new(FALSE, 0);
	gtk_box_pack_start(GTK_BOX(box), box2, TRUE, TRUE, 0);
	label = gtk_label_new(_("Mine Size:"));
	gtk_box_pack_start(GTK_BOX(box2), label, TRUE, TRUE, 0);
	gtk_widget_show(label);
	sentry = gtk_entry_new();
	gtk_widget_set_usize(sentry, 50, -1);
	gtk_box_pack_start(GTK_BOX(box2), sentry, FALSE, TRUE, 0);
	sprintf(numstr, "%d", minesize);
	gtk_entry_set_text(GTK_ENTRY(sentry),numstr);
	gtk_widget_show(sentry);
	gtk_widget_show(box2);

	gtk_box_pack_start(GTK_BOX(all_boxes), cframe, TRUE, TRUE, 0);
        gtk_widget_set_sensitive(cframe, fsize == 3);
	
	box = gtk_vbox_new(FALSE, 0);
	gtk_container_add(GTK_CONTAINER(cframe), box);

	box2 = gtk_hbox_new(FALSE, 0);
	gtk_box_pack_start(GTK_BOX(box), box2, TRUE, TRUE, 0);
	label = gtk_label_new(_("Horizontal:"));
	gtk_box_pack_start(GTK_BOX(box2), label, TRUE, TRUE, 0);
	gtk_widget_show(label);
	xentry = gtk_entry_new();
	gtk_widget_set_usize(xentry, 50, -1);
	gtk_box_pack_start(GTK_BOX(box2), xentry, FALSE, TRUE, 0);
	sprintf(numstr, "%d", xsize);
	gtk_entry_set_text(GTK_ENTRY(xentry),numstr);
	gtk_widget_show(xentry);
	gtk_widget_show(box2);

	box2 = gtk_hbox_new(FALSE, 0);
	gtk_box_pack_start(GTK_BOX(box), box2, TRUE, TRUE, 0);
	label = gtk_label_new(_("Vertical:"));
	gtk_box_pack_start(GTK_BOX(box2), label, TRUE, TRUE, 0);
	gtk_widget_show(label);
	yentry = gtk_entry_new();
	gtk_widget_set_usize(yentry, 50, -1);
	gtk_box_pack_start(GTK_BOX(box2), yentry, FALSE, TRUE, 0);
	sprintf(numstr, "%d", ysize);
	gtk_entry_set_text(GTK_ENTRY(yentry),numstr);
	gtk_widget_show(yentry);
	gtk_widget_show(box2);

	box2 = gtk_hbox_new(FALSE, 0);
	gtk_box_pack_start(GTK_BOX(box), box2, TRUE, TRUE, 0);
	label = gtk_label_new(_("Number of mines:"));
	gtk_box_pack_start(GTK_BOX(box2), label, TRUE, TRUE, 0);
	gtk_widget_show(label);
	mentry = gtk_entry_new();
	gtk_widget_set_usize(mentry, 50, -1);
	gtk_box_pack_start(GTK_BOX(box2), mentry, FALSE, TRUE, 0);
	sprintf(numstr, "%d", nmines);
	gtk_entry_set_text(GTK_ENTRY(mentry),numstr);
	gtk_widget_show(mentry);
	gtk_widget_show(box2);

	gtk_widget_show(box);
        gtk_widget_show(cframe);
	
	box = gtk_hbox_new(TRUE, 5);
	gtk_box_pack_start(GTK_BOX(all_boxes), box, TRUE, TRUE, 0);
	button = gtk_button_new_with_label(_("Ok"));
	gtk_signal_connect(GTK_OBJECT(button), "clicked",
			   GTK_SIGNAL_FUNC(do_setup), NULL);
	gtk_box_pack_start(GTK_BOX(box), button, TRUE, TRUE, 5);
        gtk_widget_show(button);
	button = gtk_button_new_with_label(_("Cancel"));
	gtk_signal_connect(GTK_OBJECT(button), "clicked",
                           (GtkSignalFunc)setupdialog_destroy,
			   (gpointer)1);
	gtk_box_pack_start(GTK_BOX(box), button, TRUE, TRUE, 5);
        gtk_widget_show(button);
        gtk_widget_show(box);
	
	gtk_widget_show(all_boxes);

        fsc = fsize;

	gtk_widget_show(setupdialog);
}

GnomeUIInfo gamemenu[] = {
	{GNOME_APP_UI_ITEM, N_("New"), NULL, new_game,
	GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_NEW, 0, 0, NULL},

	{GNOME_APP_UI_ITEM, N_("Properties..."), NULL, setup_game,
	GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_PROP, 0, 0, NULL},

	{GNOME_APP_UI_ITEM, N_("Scores..."), NULL, top_ten,
	GNOME_APP_PIXMAP_STOCK, NULL, 0, 0, NULL},

	{GNOME_APP_UI_ITEM, N_("Exit"), NULL, quit_game,
	GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_EXIT, 0, 0, NULL},

	{GNOME_APP_UI_ENDOFINFO, NULL, NULL, NULL,
	GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL}
};

GnomeUIInfo helpmenu[] = {
	{GNOME_APP_UI_HELP, NULL, NULL, NULL,
	GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

	{GNOME_APP_UI_ITEM, N_("About..."), NULL, about,
	GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_ABOUT, 0, 0, NULL},

	{GNOME_APP_UI_ENDOFINFO, NULL, NULL, NULL,
	GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL}
};

GnomeUIInfo mainmenu[] = {
	{GNOME_APP_UI_SUBTREE, N_("Game"), NULL, gamemenu,
	GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

	{GNOME_APP_UI_SUBTREE, N_("Help"), NULL, helpmenu,
	GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

	{GNOME_APP_UI_ENDOFINFO, NULL, NULL, NULL,
	GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL}
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

static GnomeClient *
parse_args (int argc, char *argv[])
{
	GnomeClient *client;
	int x_set = 0, y_set = 0, nmines_set = 0, fsize_set = 0, minesize_set = 0;
	int set_pos = 0;
	int i;
	gint xpos = 0, ypos = 0;

	/* FIXME: use GNU getopt.  Add --help, --version.  Error if option
	   unrecognized.  */
	for (i = 0; i < argc - 1; ++i)
	{
		if (! strcmp (argv[i], "-x"))
		{
			x_set = 1;
			xsize = atoi (argv[++i]);
		}
		else if (! strcmp (argv[i], "-y"))
		{
			y_set = 1;
			ysize = atoi (argv[++i]);
		}
		else if (! strcmp (argv[i], "-s"))
		{
			/* Stupid argument name; will change with long opts.  */
			minesize_set = 1;
			minesize = atoi (argv[++i]);
		}
		else if (! strcmp (argv[i], "-n"))
		{
			nmines_set = 1;
			nmines = atoi (argv[++i]);
		}
		else if (! strcmp (argv[i], "-f"))
		{
			fsize_set = 1;
			fsize = atoi (argv[++i]);
		}
		else if (! strcmp (argv[i], "-a"))
		{
			/* Stupid argument name; will change with long opts.  */
			xpos = atoi (argv[++i]);
			set_pos |= 1;
		}
		else if (! strcmp (argv[i], "-b"))
		{
			/* Stupid argument name; will change with long opts.  */
			ypos = atoi (argv[++i]);
			set_pos |= 2;
		}
		else if (! strcmp (argv[i], "--sm-client-id"))
		{
			/* Stupid argument name; will change with long opts.  */
			++i;
		}
	}

	if (set_pos == 3)
		gtk_widget_set_uposition (window, xpos, ypos);

	if (! x_set)
		xsize  = gnome_config_get_int("/gnomine/geometry/xsize=20");
	if (! y_set)
		ysize  = gnome_config_get_int("/gnomine/geometry/ysize=20");
	if (! nmines_set)
		nmines = gnome_config_get_int("/gnomine/geometry/nmines=50");
	if (! minesize_set)
		minesize = gnome_config_get_int("/gnomine/geometry/minesize=17");
	if (! fsize_set)
		fsize  = gnome_config_get_int("/gnomine/geometry/mode=0");

	client = gnome_client_new (argc, argv);
	gtk_object_ref(GTK_OBJECT(client));
	gtk_object_sink(GTK_OBJECT(client));

	gtk_signal_connect (GTK_OBJECT (client), "save_yourself",
			    GTK_SIGNAL_FUNC (save_state), argv[0]);
	return client;
}

int main(int argc, char *argv[])
{
        GtkWidget *all_boxes;
	GtkWidget *status_table;
	GtkWidget *button_table;
        GtkWidget *label;
	GnomeClient *client;

	gnome_score_init("gnomine");
	
        gnome_init("gnomine", &argc, &argv);

	bindtextdomain (PACKAGE, GNOMELOCALEDIR);
	textdomain (PACKAGE);
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

	window = gnome_app_new("gnomine", _("Gnome mines"));
        gtk_window_set_policy(GTK_WINDOW(window), FALSE, FALSE, TRUE);
	gnome_app_create_menus(GNOME_APP(window), mainmenu);
	
        gtk_signal_connect(GTK_OBJECT(window), "delete_event",
                           GTK_SIGNAL_FUNC(quit_game), NULL);

        all_boxes = gtk_vbox_new(FALSE, 0);

	gnome_app_set_contents(GNOME_APP(window), all_boxes);

	client = parse_args (argc, argv);

        button_table = gtk_table_new(1, 3, TRUE);
	gtk_box_pack_start(GTK_BOX(all_boxes), button_table, TRUE, TRUE, 0);

	label = gtk_label_new("");
	gtk_table_attach(GTK_TABLE(button_table), label,
			 0, 1, 0, 1,
			 GTK_FILL | GTK_EXPAND,
			 GTK_FILL | GTK_EXPAND,
			 0, 0);
        gtk_widget_show(label);

        pm_current = NULL;

	mbutton = gtk_button_new();
	gtk_signal_connect(GTK_OBJECT(mbutton), "clicked",
                           GTK_SIGNAL_FUNC(new_game), NULL);
        gtk_widget_set_usize(mbutton, 38, 38);
	gtk_table_attach(GTK_TABLE(button_table), mbutton, 1, 2, 0, 1,
			 0, 0, 5, 5);

	face_box = gtk_vbox_new(FALSE, 0);
	gtk_container_add(GTK_CONTAINER(mbutton), face_box);
	
	pm_win     = gnome_create_pixmap_widget_d(window, mbutton, face_win_xpm);
	pm_sad     = gnome_create_pixmap_widget_d(window, mbutton, face_sad_xpm);
	pm_smile   = gnome_create_pixmap_widget_d(window, mbutton, face_smile_xpm);
	pm_cool    = gnome_create_pixmap_widget_d(window, mbutton, face_cool_xpm);
	pm_worried = gnome_create_pixmap_widget_d(window, mbutton, face_worried_xpm);

        gtk_box_pack_start(GTK_BOX(face_box), pm_win, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(face_box), pm_sad, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(face_box), pm_smile, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(face_box), pm_cool, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(face_box), pm_worried, FALSE, FALSE, 0);

	show_face(pm_smile);

	gtk_widget_show(face_box);
	gtk_widget_show(mbutton);

	label = gtk_label_new("");
	gtk_table_attach(GTK_TABLE(button_table), label,
			 2, 3, 0, 1,
			 GTK_FILL | GTK_EXPAND,
			 GTK_FILL | GTK_EXPAND,
			 0, 0);
        gtk_widget_show(label);

	gtk_widget_show(button_table);
	
        mfieldbox = gtk_vbox_new(FALSE, 0);
	gtk_box_pack_start(GTK_BOX(all_boxes), mfieldbox, TRUE, TRUE, 0);
	gtk_widget_show(mfieldbox);

	mfield = gtk_minefield_new();
        setup_mode(mfield, fsize);
	
	gtk_box_pack_start(GTK_BOX(mfieldbox), mfield, TRUE, TRUE, 0);
	
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
        gtk_widget_show(window);

	new_game(mfield, NULL);

        gtk_main();

	gtk_object_unref(GTK_OBJECT(client));

	return 0;
}
