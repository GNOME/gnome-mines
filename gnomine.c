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
	ysize    = range (xsize, 4, 100);
	nmines   = range (nmines, 1, xsize * ysize);
}

void do_setup(GtkWidget *widget, gpointer data)
{
        guint oldxsize, oldysize, oldnmines, oldfsize;
  
	oldxsize = xsize;
	oldysize = ysize;
	oldnmines = nmines;
        oldfsize = fsize;

        xsize  = atoi(gtk_entry_get_text(GTK_ENTRY(xentry)));
	ysize  = atoi(gtk_entry_get_text(GTK_ENTRY(yentry)));
        nmines = atoi(gtk_entry_get_text(GTK_ENTRY(mentry)));
        minesize = gtk_spin_button_get_value_as_int(GTK_SPIN_BUTTON(sentry));
	fsize  = fsc;

	verify_ranges ();
        setup_mode(mfield, fsize);
  
        if ((oldxsize != xsize) ||
	    (oldysize != ysize) ||
	    (oldfsize != fsize) ||
	    (oldnmines != nmines))
          {
	    new_game(mfield, NULL);
	  }

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
        const gchar *authors[] = {
		"Code: Pista",
		"Faces: tigert",
		"Score: HoraPe",
		NULL
	};

        about = gnome_about_new (_("Gnome Mines"), VERSION,
				 "(C) 1997-1998 the Free Software Fundation",
				 (const char **)authors,
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
        GtkObject *adj;
        gchar numstr[8];
	
        if (setupdialog) return;

	setupdialog = gtk_window_new(GTK_WINDOW_DIALOG);

	gtk_container_border_width(GTK_CONTAINER(setupdialog), 10);
	GTK_WINDOW(setupdialog)->position = GTK_WIN_POS_MOUSE;
	gtk_window_set_title(GTK_WINDOW(setupdialog), _("Gnome Mines setup"));
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
        gtk_box_pack_start(GTK_BOX(box2), sentry, FALSE, TRUE, 0);
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
        button = gnome_stock_button(GNOME_STOCK_BUTTON_OK);
	gtk_signal_connect(GTK_OBJECT(button), "clicked",
			   GTK_SIGNAL_FUNC(do_setup), NULL);
	gtk_box_pack_start(GTK_BOX(box), button, TRUE, TRUE, 5);
        gtk_widget_show(button);
        button = gnome_stock_button(GNOME_STOCK_BUTTON_CANCEL);
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
	{GNOME_APP_UI_ITEM, N_("_New"), NULL, new_game, NULL, NULL,
	GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_NEW, 'n', GDK_CONTROL_MASK, NULL},

	{GNOME_APP_UI_ITEM, N_("_Properties..."), NULL, setup_game, NULL, NULL,
	GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_PROP, 0, 0, NULL},

	{GNOME_APP_UI_ITEM, N_("_Scores..."), NULL, top_ten, NULL, NULL,
	GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_SCORES, 0, 0, NULL},

	{GNOME_APP_UI_ITEM, N_("Quit"), NULL, quit_game, NULL, NULL,
	GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_EXIT, 'q', GDK_CONTROL_MASK, NULL},

	{GNOME_APP_UI_ENDOFINFO, NULL, NULL, NULL, NULL, NULL,
	GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL}
};

GnomeUIInfo helpmenu[] = {
	{GNOME_APP_UI_HELP, NULL, NULL, "gnomine", NULL, NULL,
	GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

	{GNOME_APP_UI_ITEM, N_("_About..."), NULL, about, NULL, NULL,
	GNOME_APP_PIXMAP_STOCK, GNOME_STOCK_MENU_ABOUT, 0, 0, NULL},

	{GNOME_APP_UI_ENDOFINFO, NULL, NULL, NULL, NULL, NULL,
	GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL}
};

GnomeUIInfo mainmenu[] = {
	{GNOME_APP_UI_SUBTREE, N_("_Game"), NULL, gamemenu, NULL, NULL,
	GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

	{GNOME_APP_UI_SUBTREE, N_("_Help"), NULL, helpmenu, NULL, NULL,
	GNOME_APP_PIXMAP_NONE, NULL, 0, 0, NULL},

	{GNOME_APP_UI_ENDOFINFO}
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
        GtkWidget *all_boxes;
	GtkWidget *status_table;
	GtkWidget *button_table;
        GtkWidget *align;
        GtkWidget *label;
	GnomeClient *client;

	bindtextdomain (PACKAGE, GNOMELOCALEDIR);
	textdomain (PACKAGE);

	gnome_score_init("gnomine");

	client = gnome_client_new_default ();
	gtk_signal_connect (GTK_OBJECT (client), "save_yourself",
			    GTK_SIGNAL_FUNC (save_state), argv[0]);

        gnome_init_with_popt_table("gnomine", VERSION, argc, argv,
				   options, 0, NULL);

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

        window = gnome_app_new("gnomine", _("Gnome mines"));
        gtk_window_set_policy(GTK_WINDOW(window), FALSE, FALSE, TRUE);
	gnome_app_create_menus(GNOME_APP(window), mainmenu);
        gtk_menu_item_right_justify(GTK_MENU_ITEM(mainmenu[1].widget));

	
        gtk_signal_connect(GTK_OBJECT(window), "delete_event",
                           GTK_SIGNAL_FUNC(quit_game), NULL);

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
        mfield = gtk_minefield_new();
	gtk_widget_pop_colormap ();
	gtk_widget_pop_visual ();
        gtk_container_add (GTK_CONTAINER (align), mfield);

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
        gtk_widget_show(window);

	new_game(mfield, NULL);

        gtk_main();

	gtk_object_unref(GTK_OBJECT(client));

	return 0;
}
