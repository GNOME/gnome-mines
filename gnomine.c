
#include <gtk/gtk.h>
#include <gnome.h>
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
GtkWidget *mbutton;
GtkWidget *plabel;
GtkWidget *cframe;
GtkWidget *clk;
GtkWidget *pm_win, *pm_sad, *pm_smile, *pm_cool, *pm_worried, *pm_current;
GtkWidget *face_box;
guint ysize, xsize;
guint nmines;
guint fsize, fsc;

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
        gtk_main_quit();
}

void set_flabel(GtkMineField *mfield)
{
	char val[16];

	sprintf(val, "%d/%d", mfield->flags, mfield->mcount);
	gtk_label_set(GTK_LABEL(flabel), val);
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
        show_face(pm_win);
        gtk_clock_stop(GTK_CLOCK(clk));

	score = (1000 * (gfloat)nmines /
		 ((gfloat)xsize * (gfloat)ysize * (gfloat)GTK_CLOCK(clk)->stopped));

	if(gnome_score_log(score))
	  {
	    GtkWidget *mb;
	    gchar buf[512];
	    snprintf(buf, sizeof(buf), "You got onto the high score list with a score of %.0f!", score);
	    mb = gnome_messagebox_new(buf, GNOME_MESSAGEBOX_INFO, "OK",
				      NULL, NULL);
	    gnome_messagebox_set_default(GNOME_MESSAGEBOX(mb), 0);
	    gnome_messagebox_set_modal(GNOME_MESSAGEBOX(mb));
	    gtk_widget_show(mb);
	  }
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
	gint x,y,m;

	if (mode == 3) {
		x = xsize;
		y = ysize;
		m = nmines;
	} else {
		x = size_table[mode][0];
		y = size_table[mode][1];
		m = size_table[mode][2];
	}
	gtk_minefield_set_size(GTK_MINEFIELD(mfield), x, y);
	gtk_minefield_set_mines(GTK_MINEFIELD(mfield), m);
}

void do_setup(GtkWidget *widget, gpointer data)
{

	xsize  = atoi(gtk_entry_get_text(GTK_ENTRY(xentry)));
	ysize  = atoi(gtk_entry_get_text(GTK_ENTRY(yentry)));
        nmines = atoi(gtk_entry_get_text(GTK_ENTRY(mentry)));
	fsize  = fsc;
	
        setup_mode(mfield, fsize);
	new_game(mfield, NULL);

	setupdialog_destroy(setupdialog, 1);

	gnome_config_set_int("/gnomine/geometry/xsize",  xsize);
	gnome_config_set_int("/gnomine/geometry/ysize",  ysize);
	gnome_config_set_int("/gnomine/geometry/nmines", nmines);
	gnome_config_set_int("/gnomine/geometry/mode",   fsize);
	gnome_config_sync();
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
	gtk_window_set_title(GTK_WINDOW(setupdialog), "Gnome mines setup");
	gtk_signal_connect(GTK_OBJECT(setupdialog),
			   "delete_event",
			   GTK_SIGNAL_FUNC(setupdialog_destroy),
			   0);

	all_boxes = gtk_vbox_new(FALSE, 5);
	gtk_container_add(GTK_CONTAINER(setupdialog), all_boxes);

        cframe = gtk_frame_new("Custom size");

	frame = gtk_frame_new("Field size");
	gtk_box_pack_start(GTK_BOX(all_boxes), frame, TRUE, TRUE, 0);
	
	box = gtk_vbox_new(FALSE, 0);
	gtk_container_add(GTK_CONTAINER(frame), box);
	
	button = gtk_radio_button_new_with_label(NULL, "Tiny");
	if (fsize == 0) gtk_toggle_button_set_state(GTK_TOGGLE_BUTTON (button), TRUE);
	gtk_signal_connect(GTK_OBJECT(button), "clicked", GTK_SIGNAL_FUNC(size_radio_callback),
			   (gpointer) 0);
	gtk_box_pack_start(GTK_BOX(box), button, TRUE, TRUE, 0);
        gtk_widget_show(button);

	button = gtk_radio_button_new_with_label(gtk_radio_button_group(GTK_RADIO_BUTTON(button)),
						 "Medium");
	if (fsize == 1) gtk_toggle_button_set_state(GTK_TOGGLE_BUTTON (button), TRUE);
	gtk_signal_connect(GTK_OBJECT(button), "clicked", GTK_SIGNAL_FUNC(size_radio_callback),
			   (gpointer) 1);
	gtk_box_pack_start(GTK_BOX(box), button, TRUE, TRUE, 0);
        gtk_widget_show(button);

	button = gtk_radio_button_new_with_label(gtk_radio_button_group(GTK_RADIO_BUTTON(button)),
						 "Biiiig");
	if (fsize == 2) gtk_toggle_button_set_state(GTK_TOGGLE_BUTTON (button), TRUE);
	gtk_signal_connect(GTK_OBJECT(button), "clicked", GTK_SIGNAL_FUNC(size_radio_callback),
			   (gpointer) 2);
	gtk_box_pack_start(GTK_BOX(box), button, TRUE, TRUE, 0);
        gtk_widget_show(button);
	
	button = gtk_radio_button_new_with_label(gtk_radio_button_group(GTK_RADIO_BUTTON(button)),
						 "Custom");
	if (fsize == 3) gtk_toggle_button_set_state(GTK_TOGGLE_BUTTON (button), TRUE);
	gtk_signal_connect(GTK_OBJECT(button), "clicked", GTK_SIGNAL_FUNC(size_radio_callback),
			   (gpointer) 3);
	gtk_box_pack_start(GTK_BOX(box), button, TRUE, TRUE, 0);
        gtk_widget_show(button);

	gtk_widget_show(box);
	gtk_widget_show(frame);

	gtk_box_pack_start(GTK_BOX(all_boxes), cframe, TRUE, TRUE, 0);
        gtk_widget_set_sensitive(cframe, fsize == 3);
	
	box = gtk_vbox_new(FALSE, 0);
	gtk_container_add(GTK_CONTAINER(cframe), box);

	box2 = gtk_hbox_new(FALSE, 0);
	gtk_box_pack_start(GTK_BOX(box), box2, TRUE, TRUE, 0);
	label = gtk_label_new("Horizontal:");
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
	label = gtk_label_new("Vertical:");
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
	label = gtk_label_new("Number of mines:");
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
	button = gtk_button_new_with_label("Ok");
	gtk_signal_connect(GTK_OBJECT(button), "clicked",
			   GTK_SIGNAL_FUNC(do_setup), NULL);
	gtk_box_pack_start(GTK_BOX(box), button, TRUE, TRUE, 5);
        gtk_widget_show(button);
	button = gtk_button_new_with_label("Cancel");
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

GnomeMenuInfo gamemenu[] = {
  {GNOME_APP_MENU_ITEM, "New", new_game, NULL},
  {GNOME_APP_MENU_ITEM, "Setup...", setup_game, NULL},
  {GNOME_APP_MENU_ITEM, "Exit", quit_game, NULL},
  {GNOME_APP_MENU_ENDOFINFO, NULL, NULL, NULL}  
};

GnomeMenuInfo mainmenu[] = {
  {GNOME_APP_MENU_SUBMENU, "Game", gamemenu, NULL},
  {GNOME_APP_MENU_ENDOFINFO, NULL, NULL, NULL}
};

int main(int argc, char *argv[])
{
        GtkWidget *all_boxes;
	GtkWidget *status_table;
	GtkWidget *button_table;
        GtkWidget *label;
	
        gtk_init(&argc, &argv);
        gnome_init(&argc, &argv);

	window = gnome_app_new("gnomine", "Gnome mines");
        gtk_window_set_policy(GTK_WINDOW(window), FALSE, FALSE, TRUE);
	gnome_app_create_menus(GNOME_APP(window), mainmenu);
        
        gtk_signal_connect(GTK_OBJECT(window), "delete_event",
                           GTK_SIGNAL_FUNC(quit_game), NULL);

        all_boxes = gtk_vbox_new(FALSE, 0);

	gnome_app_set_contents(GNOME_APP(window), all_boxes);

	xsize  = gnome_config_get_int("/gnomine/geometry/xsize=20");
	ysize  = gnome_config_get_int("/gnomine/geometry/ysize=20");
	nmines = gnome_config_get_int("/gnomine/geometry/nmines=50");
	fsize  = gnome_config_get_int("/gnomine/geometry/mode=0");

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

	label = gtk_label_new("Flags:");
	gtk_table_attach(GTK_TABLE(status_table), label,
			 0, 1, 0, 1, 0, 0, 3, 3);
	gtk_widget_show(label);
	
	flabel = gtk_label_new("0");
	
	gtk_table_attach(GTK_TABLE(status_table), flabel,
			 1, 2, 0, 1, 0, 0, 3, 3);
	gtk_widget_show(flabel);

	label = gtk_label_new("Time:");
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

	return 0;
}



