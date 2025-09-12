/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright © 2025 Will Warner
 *
 * This file is part of libgnome-games-support.
 *
 * libgnome-games-support is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * libgnome-games-support is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with libgnome-games-support.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Games {

public class ThemeSelectorDialog : Adw.Dialog
{
    /**
     * The index of the theme the user has selected.
     *
     */
    public uint active_index = -1;
    private ListStore themes;
    private Adw.Bin theme_bin;
    private Gtk.Button prev_button;
    private Gtk.Button next_button;
    private Gtk.Builder builder;

    /**
     * Emitted when the active_theme is changed
     *
     */
    public signal void theme_changed (uint index);

    /**
     * Creates a new ThemeSelectorDialog
     *
     * `themes` contains a preview widget for each theme in your game.
     * If `themes` is empty, the dialog will break.
     *
     */
    public ThemeSelectorDialog (ListStore themes)
    {
        this.themes = themes;
        this.active_index = 0;
        builder = new Gtk.Builder ();
        Adw.ToolbarView toolbar = new Adw.ToolbarView ();
        Adw.HeaderBar headerbar = new Adw.HeaderBar ();
        set_title ("Select Theme");
        headerbar.set_show_start_title_buttons (true);
        headerbar.set_show_end_title_buttons (true);
        Gtk.Box buttons_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        prev_button = new Gtk.Button.from_icon_name ("go-previous-symbolic");
        next_button = new Gtk.Button.from_icon_name ("go-next-symbolic");
        prev_button.set_tooltip_text ("Previous");
        next_button.set_tooltip_text ("Next");
        next_button.clicked.connect (() => {
            ++active_index;
            update ();

        });
        prev_button.clicked.connect (() => {
            --active_index;
            update ();
        });
        buttons_box.append (prev_button);
        buttons_box.append (next_button);
        headerbar.pack_start (buttons_box);
        toolbar.add_child (builder, headerbar, "top");
        set_child (toolbar);
        theme_bin = new Adw.Bin ();
        update ();
        toolbar.add_child (builder, theme_bin, null);
    }

    private void update () {
        next_button.set_sensitive (active_index < themes.get_n_items () - 1);
        prev_button.set_sensitive (active_index > 0);
        theme_bin.set_child (themes.get_item (active_index) as Gtk.Widget);
    }
}

} /* namespace Games */
