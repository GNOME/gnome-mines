public class Tile : Gtk.Button
{
    private int _row;
    private int _column;
    private Gtk.GestureLongPress _gesture;
    public signal void tile_mouse_over (int x, int y);
    public signal void tile_pressed (int x, int y, Gdk.EventButton event);
    public signal void tile_released (int x, int y, Gdk.EventButton event);
    public signal void tile_long_pressed (int x, int y);

    public int row
    {
        get { return _row; }
    }
    public int column
    {
        get { return _column; }
    }

    public Tile (int prow, int pcol)
    {
        _row = prow;
        _column = pcol;
        can_focus = false;
        add_class ("tile");
        _gesture = new Gtk.GestureLongPress (this);
        _gesture.pressed.connect((x, y) =>
        {
            tile_long_pressed (prow, pcol);
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
    }

    public void remove_class (string style_class)
    {
        get_style_context ().remove_class (style_class);
    }
}
