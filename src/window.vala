/*
 * Copyright (C) 2011-2012 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class MineWindow : Adw.ApplicationWindow
{

    private GLib.Settings settings;
    private Gtk.CssProvider theme_provider;

    public const string KEY_THEME = "theme";

    construct
    {
        settings = new GLib.Settings ("org.gnome.Mines");

        set_game_theme (settings.get_string (KEY_THEME));
        settings.changed[KEY_THEME].connect (() => {
            set_game_theme (settings.get_string (KEY_THEME));
        });

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

    private void set_game_theme (string theme)
    {
        string theme_path = theme;
        bool is_switch = theme_provider != null;
        Gdk.Display display = get_display ();

        if (!Path.is_absolute (theme_path)) {
            theme_path = Path.build_path (Path.DIR_SEPARATOR_S, DATA_DIRECTORY, "themes", theme);
        }
        if (!is_switch) {
            Gtk.IconTheme.get_for_display (display).add_search_path (theme_path);
        } else {
            Gtk.IconTheme icon_theme = Gtk.IconTheme.get_for_display (display);
            string[] icon_search_path = icon_theme.get_search_path ();
            icon_search_path[icon_search_path.length - 1] = theme_path;
            icon_theme.set_search_path (icon_search_path);
        }

        var theme_css_path = Path.build_filename (theme_path, "theme.css");
        if (is_switch) {
            // There is no way to remove depredations here without completely remolding this.
            Gtk.StyleContext.remove_provider_for_display (display, theme_provider);
        }
        theme_provider = new Gtk.CssProvider ();
        theme_provider.load_from_path (theme_css_path);
        Gtk.StyleContext.add_provider_for_display (display, theme_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        queue_draw ();
    }
}
