/*
 * Copyright (C) 2011-2012 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class MineWindow : Gtk.ApplicationWindow
{

    private GLib.Settings settings;

    construct
    {
        settings = new GLib.Settings ("org.gnome.Mines");

        load_window_state ();
    }

    public override bool close_request ()
    {
        save_window_state ();

        return base.close_request ();
    }

    private void load_window_state ()
    {
        var window_maximized = settings.get_boolean ("window-is-maximized");

        if (window_maximized) {
            maximize ();
        } else {
            var width = settings.get_int ("window-width");
            var height = settings.get_int ("window-height");
            set_default_size (width, height);
        }
    }

    private void save_window_state ()
    {
        var width = 0;
        var height = 0;

        get_default_size (out width, out height);

        debug ("Saving window geometry: %i × %i", width, height);

        settings.set_int ("window-width", width);
        settings.set_int ("window-height", height);

        settings.set_boolean ("window-is-maximized", is_maximized ());
    }
}
