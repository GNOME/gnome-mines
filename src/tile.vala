using Gtk;

public class Tile : Widget
{
    public int row      { internal get; protected construct; }
    public int column   { internal get; protected construct; }

    private GestureLongPress _gesture;                  // for keeping in memory
    private GestureClick _click_controller;             // for keeping in memory

    public signal void tile_mouse_over (int x, int y);
    public signal void tile_pressed (int x, int y, uint button, int n_press, bool ctrl);
    public signal void tile_released (int x, int y, uint button);
    public signal void tile_long_pressed (int x, int y);

    public Tile (int prow, int pcol)
    {
        Object (row: prow, column: pcol);
    }

    construct
    {
        add_css_class ("tile");

        _gesture = new GestureLongPress ();
        _gesture.touch_only = true;
        _gesture.pressed.connect((x, y) =>
        {
            tile_long_pressed (row, column);
        });
        add_controller (_gesture);

        _click_controller = new GestureClick ();
        _click_controller.set_button (/* all buttons */ 0);
        _click_controller.pressed.connect ((click_controller, n_press, x, y) =>
        {
            /* By default windows with both button press and button release
             * grab Gdk events, ungrab events here for other tiles. */
//            event.get_seat().ungrab ();       // TODO do something instead?
//            event.device.ungrab (event.time);

            Gdk.ModifierType state = click_controller.get_current_event_state ();
            bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
            uint button = click_controller.get_current_button ();
            tile_pressed (row, column, button, n_press, ctrl);
        });
        _click_controller.released.connect ((click_controller, n_press, x, y) =>
        {
            uint button = click_controller.get_current_button ();
            tile_released (row, column, button);
        });
        add_controller (_click_controller);
    }
}
