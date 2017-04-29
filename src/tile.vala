public class Tile : Gtk.Button
{
    private int _row;
    private int _column;
    public signal void tile_mouse_over (int x, int y);
    public signal void tile_pressed (int x, int y, Gdk.EventButton event);
    public signal void tile_released (int x, int y, Gdk.EventButton event);
    private static string[] IMAGE_CLASSES = {"mine", "flag", "incorrect",
                                             "maybe", "overmine",
                                             "exploded", "1mines", "2mines",
                                             "3mines", "4mines", "5mines",
                                             "6mines", "7mines", "8mines"};
    private Gtk.Image scaling_image;

    public int row
    {
        get { return _row; }
    }
    public int column
    {
        get { return _column; }
    }

    public void refresh_icon ()
    {
        string name;
        Gtk.IconSize size;
        scaling_image.get_icon_name (out name, out size);
        scaling_image.clear ();
        scaling_image.set_from_icon_name (name, size);
        scaling_image.set_pixel_size (get_allocated_height ()/3*2);
        set_image (scaling_image);
    }

    public Tile (int prow, int pcol)
    {
        _row = prow;
        _column = pcol;
        scaling_image = new Gtk.Image ();
        can_focus = false;
        add_class ("tile");
        set_image (scaling_image);
        size_allocate.connect ((allocation) =>
        {
            scaling_image.set_pixel_size (allocation.height/3*2);
        });
        button_press_event.connect ((event) =>
        {
            /* By default windows with both button press and button release
             * grab Gdk events, ungrab events here for other tiles. */
            event.get_seat().ungrab ();
//            event.device.ungrab (event.time);

            tile_pressed (prow, pcol, event);
            return false;
        });
        button_release_event.connect ((event) =>
        {
            tile_released (prow, pcol, event);
            return false;
        });
    }

    public void add_class (string style_class)
    {
        get_style_context ().add_class (style_class);
        if (style_class in IMAGE_CLASSES) {
            scaling_image.set_from_icon_name (style_class, Gtk.IconSize.DND);
            scaling_image.set_pixel_size (get_allocated_height ()/3*2);
            set_image (scaling_image);
        }
    }

    public void remove_class (string style_class)
    {
        get_style_context ().remove_class (style_class);
        if (style_class in IMAGE_CLASSES) {
            scaling_image = new Gtk.Image ();
            set_image (scaling_image);
        }
    }
}

