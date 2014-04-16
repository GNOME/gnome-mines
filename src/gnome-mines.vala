/*
 * Copyright (C) 2011-2012 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class Mines : Gtk.Application
{
    /* Settings keys */
    private Settings settings;
    private const string KEY_XSIZE = "xsize";
    private const int XSIZE_MIN = 4;
    private const int XSIZE_MAX = 100;
    private const string KEY_YSIZE = "ysize";
    private const int YSIZE_MIN = 4;
    private const int YSIZE_MAX = 100;
    private const string KEY_NMINES = "nmines";
    private const string KEY_MODE = "mode";

    /* Keys shared with MinefieldView */
    public static const string KEY_USE_QUESTION_MARKS = "use-question-marks";
    public static const string KEY_USE_OVERMINE_WARNING = "use-overmine-warning";
    public static const string KEY_USE_AUTOFLAG = "use-autoflag";

    private Gtk.Box buttons_box;
    private Gtk.Button play_pause_button;
    private Gtk.Button replay_button;
    private Gtk.Button high_scores_button;
    private Gtk.Button new_game_button;
    private Gtk.AspectFrame minefield_aspect;
    private Gtk.Overlay minefield_overlay;
    private Gtk.Box paused_box;

    private Gtk.Label clock_label;

    private Menu app_main_menu;

    /* Main window */
    private Gtk.Window window;
    private int window_width;
    private int window_height;
    private bool is_maximized;

    /* true when the user has requested the game to pause. */
    private bool pause_requested;

    /* true when the next configure event should be ignored. */
    private bool window_skip_configure;
    
    /* Game history */
    private History history;

    /* Minefield being played */
    private Minefield minefield;

    /* Minefield widget */
    private MinefieldView minefield_view;

    /* Game status */
    private Gtk.Label flag_label;

    private Gtk.SpinButton mines_spin;
    private SimpleAction new_game_action;
    private SimpleAction repeat_size_action;
    private SimpleAction pause_action;
    private Gtk.AspectFrame new_game_screen;
    private Gtk.AspectFrame custom_game_screen;
    private bool is_new_game_screen;

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",           new_game_cb                                   },
        { "repeat-size",        repeat_size_cb                                },
        { "pause",              toggle_pause_cb                               },
        { "scores",             scores_cb                                     },
        { "quit",               quit_cb                                       },
        { "help",               help_cb                                       },
        { "about",              about_cb                                      }
    };

    public Mines ()
    {
        Object (application_id: "org.gnome.mines", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void startup ()
    {
        base.startup ();

        Environment.set_application_name (_("Mines"));

        settings = new Settings ("org.gnome.mines");
        settings.delay ();

        Gtk.Window.set_default_icon_name ("gnome-mines");

        var css_provider = new Gtk.CssProvider ();
        var css_path = Path.build_filename (DATA_DIRECTORY, "gnome-mines.css");
        try
        {
            css_provider.load_from_path (css_path);
        }
        catch (GLib.Error e)
        {
            warning ("Error loading css styles from %s: %s", css_path, e.message);
        }
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        add_action_entries (action_entries, this);
        new_game_action = lookup_action ("new-game") as SimpleAction;
        new_game_action.set_enabled (false);
        repeat_size_action = lookup_action ("repeat-size") as SimpleAction;
        repeat_size_action.set_enabled (false);
        pause_action = lookup_action ("pause") as SimpleAction;
        pause_action.set_enabled (false);
        add_action (settings.create_action (KEY_USE_OVERMINE_WARNING));
        add_action (settings.create_action (KEY_USE_QUESTION_MARKS));

        var menu = new Menu ();
        app_main_menu = new Menu ();
        menu.append_section (null, app_main_menu);
        app_main_menu.append (_("_New Game"), "app.new-game");
        app_main_menu.append (_("_Scores"), "app.scores");
        var section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Show Warnings"), "app.%s".printf (KEY_USE_OVERMINE_WARNING));
        section.append (_("_Use Question Flags"), "app.%s".printf (KEY_USE_QUESTION_MARKS));
        section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Help"), "app.help");
        section.append (_("_About"), "app.about");
        section.append (_("_Quit"), "app.quit");
        set_app_menu (menu);

        add_accelerator ("<Primary>n", "app.new-game", null);
        add_accelerator ("<Primary>r", "app.repeat-size", null);
        add_accelerator ("Pause", "app.pause", null);
        add_accelerator ("F1", "app.help", null);
        add_accelerator ("<Primary>w", "app.quit", null);
        add_accelerator ("<Primary>q", "app.quit", null);

        window = new Gtk.ApplicationWindow (this);
        window.title = _("Mines");
        window.icon_name = "gnome-mines";
        window.configure_event.connect (window_configure_event_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.focus_out_event.connect (window_focus_out_event_cb);
        window.focus_in_event.connect (window_focus_in_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        window.set_size_request (550, 475);
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        window.get_settings ().gtk_application_prefer_dark_theme = true;

        var headerbar = new Gtk.HeaderBar ();
        headerbar.show_close_button = true;
        headerbar.set_title (_("Mines"));
        headerbar.show ();
        window.set_titlebar (headerbar);

        add_window (window);

        var main_vbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        main_vbox.margin = 12;
        window.add (main_vbox);
        main_vbox.show ();

        var view_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        view_box.border_width = 3;
        view_box.show ();
        main_vbox.pack_start (view_box, true, true, 0);

        minefield_view = new MinefieldView (settings);
        minefield_view.show ();

        minefield_overlay = new Gtk.Overlay ();
        minefield_overlay.add (minefield_view);
        minefield_overlay.show ();

        minefield_aspect = new Gtk.AspectFrame (null, 0.5f, 0.5f, 1.0f , false);
        minefield_aspect.set_shadow_type (Gtk.ShadowType.NONE);
        minefield_aspect.add (minefield_overlay);

        var paused_label = new Gtk.Label (_("Paused"));
        paused_label.halign = Gtk.Align.CENTER;
        paused_label.valign = Gtk.Align.CENTER;
        paused_label.show ();

        paused_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        paused_box.expand = true;
        paused_box.pack_start (paused_label, true, true, 0);
        paused_box.get_style_context ().add_class ("pausedOverlay");
        paused_box.button_press_event.connect (view_button_press_event);

        minefield_overlay.add_overlay (paused_box);

        view_box.pack_start (minefield_aspect, true, true, 0);

        /* Initialize New Game Screen */
        startup_new_game_screen ();
        view_box.pack_start (new_game_screen, true, true, 0);

        /* Initialize Custom Game Screen */
        startup_custom_game_screen ();
        view_box.pack_start (custom_game_screen, false, false);

        history = new History (Path.build_filename (Environment.get_user_data_dir (), "gnome-mines", "history"));
        history.load ();

        buttons_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        buttons_box.margin_right = 6;
        buttons_box.margin_left = 6;
        buttons_box.set_size_request (115, -1);

        main_vbox.pack_start (buttons_box, false, false, 0);

        var size = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        // Obviously a FIXME image
        var image = new Gtk.Image.from_icon_name ("preferences-desktop-locale-symbolic", Gtk.IconSize.DND);
        box.pack_start (image, false, false, 0);
        flag_label = new Gtk.Label ("");
        box.pack_start (flag_label, false, false, 0);
        buttons_box.pack_start (box, false, false, 8);
        box.show_all ();

        box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        image = new Gtk.Image.from_icon_name ("preferences-system-time-symbolic", Gtk.IconSize.DND);
        box.pack_start (image, false, false, 0);
        clock_label = new Gtk.Label ("");
        clock_label.show ();
        box.pack_start (clock_label, false, false, 0);
        buttons_box.pack_start (box, false, false, 8);
        box.show_all ();
        box.margin_bottom = 18;

        play_pause_button = new Gtk.Button ();
        buttons_box.pack_end (play_pause_button, false, false, 0);
        size.add_widget (play_pause_button);
        play_pause_button.use_underline = true;

        high_scores_button = new Gtk.Button.with_mnemonic (_("_Best Times"));
        var label = (Gtk.Label)high_scores_button.get_child ();
        label.wrap = true;
        label.justify = Gtk.Justification.CENTER;
        buttons_box.pack_end (high_scores_button, false, false, 0);
        high_scores_button.action_name = "app.scores";
        size.add_widget (high_scores_button);

        new_game_button = new Gtk.Button.with_mnemonic (_("_Difficulty"));
        label = (Gtk.Label)new_game_button.get_child ();
        label.wrap = true;
        label.justify = Gtk.Justification.CENTER;
        buttons_box.pack_end (new_game_button, false, false, 0);
        size.add_widget (new_game_button);
        new_game_button.action_name = "app.new-game";
        new_game_button.show ();

        replay_button = new Gtk.Button.with_mnemonic (_("_Play Again"));
        label = (Gtk.Label)replay_button.get_child ();
        label.wrap = true;
        label.justify = Gtk.Justification.CENTER;
        buttons_box.pack_end (replay_button, false, false, 0);
        replay_button.action_name = "app.repeat-size";
        size.add_widget (replay_button);
    }

    private void startup_new_game_screen ()
    {
        new_game_screen = new Gtk.AspectFrame (null, 0.5f, 0.5f, 1.0f, false);
        new_game_screen.set_shadow_type (Gtk.ShadowType.NONE);

        var new_game_grid = new Gtk.Grid ();
        new_game_grid.column_homogeneous = true;
        new_game_grid.column_spacing = 18;
        new_game_grid.row_homogeneous = true;
        new_game_grid.row_spacing = 18;
        new_game_screen.add (new_game_grid);

        var button = new Gtk.Button ();
        button.clicked.connect (small_size_clicked_cb);
        new_game_grid.attach (button, 0, 0, 1, 1);

        var label = new Gtk.Label (null);
        label.set_markup (make_minefield_description (8, 8, 10));
        label.set_justify (Gtk.Justification.CENTER);
        button.add (label);

        button = new Gtk.Button ();
        button.clicked.connect (medium_size_clicked_cb);
        new_game_grid.attach (button, 1, 0, 1, 1);

        label = new Gtk.Label (null);
        label.set_markup (make_minefield_description (16, 16, 40));
        label.set_justify (Gtk.Justification.CENTER);
        button.add (label);

        button = new Gtk.Button ();
        button.clicked.connect (large_size_clicked_cb);
        new_game_grid.attach (button, 0, 1, 1, 1);

        label = new Gtk.Label (null);
        label.set_markup (make_minefield_description (30, 16, 99));
        label.set_justify (Gtk.Justification.CENTER);
        button.add (label);

        button = new Gtk.Button ();
        button.clicked.connect (show_custom_game_screen);
        new_game_grid.attach (button, 1, 1, 1, 1);

        label = new Gtk.Label (null);
        label.set_markup_with_mnemonic ("<span size='xx-large' weight='heavy'>?</span>\n" + dpgettext2 (null, "board size", _("Custom")));
        label.set_justify (Gtk.Justification.CENTER);
        button.add (label);

        new_game_screen.show_all ();
    }

    private void startup_custom_game_screen ()
    {
        custom_game_screen = new Gtk.AspectFrame ("", 0.5f, 0.5f, 0.0f, true);
        custom_game_screen.set_shadow_type (Gtk.ShadowType.NONE);

        var custom_game_grid = new Gtk.Grid ();
        custom_game_grid.column_homogeneous = false;
        custom_game_grid.column_spacing = 12;
        custom_game_grid.row_spacing = 6;
        custom_game_screen.add (custom_game_grid);

        var label = new Gtk.Label.with_mnemonic (_("_Height:"));
        label.set_alignment (0, 0.5f);
        custom_game_grid.attach (label, 0, 0, 1, 1);

        var field_width_entry = new Gtk.SpinButton.with_range (XSIZE_MIN, XSIZE_MAX, 1);
        field_width_entry.value_changed.connect (xsize_spin_cb);
        field_width_entry.set_value (settings.get_int (KEY_XSIZE));
        custom_game_grid.attach (field_width_entry, 1, 0, 1, 1);
        label.set_mnemonic_widget (field_width_entry);

        label = new Gtk.Label.with_mnemonic (_("_Width:"));
        label.set_alignment (0, 0.5f);
        custom_game_grid.attach (label, 0, 1, 1, 1);

        var field_height_entry = new Gtk.SpinButton.with_range (YSIZE_MIN, YSIZE_MAX, 1);
        field_height_entry.value_changed.connect (ysize_spin_cb);
        field_height_entry.set_value (settings.get_int (KEY_YSIZE));
        custom_game_grid.attach (field_height_entry, 1, 1, 1, 1);
        label.set_mnemonic_widget (field_height_entry);

        label = new Gtk.Label.with_mnemonic (_("Percent _mines:"));
        label.set_alignment (0, 0.5f);
        custom_game_grid.attach (label, 0, 2, 1, 1);

        mines_spin = new Gtk.SpinButton.with_range (1, 100, 1);
        mines_spin.value_changed.connect (mines_spin_cb);
        custom_game_grid.attach (mines_spin, 1, 2, 1, 1);
        set_mines_limit ();
        label.set_mnemonic_widget (mines_spin);

        var button_grid = new Gtk.Grid ();
        button_grid.margin_top = 18;
        button_grid.row_spacing = 5;
        custom_game_grid.attach (button_grid, 0, 3, 2, 1);

        var button = new Gtk.Button.with_mnemonic (_("_Cancel"));
        button.valign = Gtk.Align.CENTER;
        button.expand = true;
        button.clicked.connect (show_new_game_screen);
        button_grid.attach (button, 0, 1, 1, 1);

        button = new Gtk.Button.with_mnemonic (_("_Play Game"));
        button.valign = Gtk.Align.CENTER;
        button.expand = true;
        button.clicked.connect (custom_size_clicked_cb);
        button.get_style_context ().add_class ("suggested-action");
        button_grid.attach (button, 0, 0, 1, 1);

        custom_game_screen.show_all ();
        custom_game_screen.hide ();
    }

    private bool window_configure_event_cb (Gdk.EventConfigure event)
    {
        if (!is_maximized && !window_skip_configure)
        {
            window_width = event.width;
            window_height = event.height;
        }

        window_skip_configure = false;

        return false;
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        return false;
    }

    private bool window_focus_out_event_cb (Gdk.EventFocus event)
    {
        if (minefield != null && minefield.is_clock_started ())
            minefield.paused = true;

        return false;
    }

    private bool window_focus_in_event_cb (Gdk.EventFocus event)
    {
        if (minefield != null && !pause_requested)
            minefield.paused = false;

        return false;
    }

    private string make_minefield_description (int width, int height, int n_mines)
    {
        var size_label = "%d × %d".printf (width, height);
        var mines_label = ngettext ("<b>%d</b> mine", "<b>%d</b> mines", n_mines).printf (n_mines);
        return "<span size='x-large' weight='ultrabold'>%s</span>\n%s".printf (size_label, mines_label);
    }

    public void start ()
    {
        window.show ();
        show_new_game_screen ();
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        /* Save window state */
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", is_maximized);
        settings.apply ();
    }

    public override void activate ()
    {
        window.show ();
    }

    private bool view_button_press_event (Gtk.Widget widget, Gdk.EventButton event)
    {
        /* Cancel pause on click */
        if (minefield.paused)
        {
            minefield.paused = false;
            pause_requested = false;
            return true;
        }

        return false;
    }

    private void quit_cb ()
    {
        window.destroy ();
    }

    private void update_flag_label ()
    {
        flag_label.set_text ("%u/%u".printf (minefield.n_flags, minefield.n_mines));
    }

    private int show_scores (HistoryEntry? selected_entry = null, bool show_close = false)
    {
        var dialog = new ScoreDialog (history, selected_entry, show_close);
        dialog.modal = true;
        dialog.transient_for = window;

        var result = dialog.run ();
        dialog.destroy ();

        return result;
    }

    private void scores_cb ()
    {
        show_scores ();
    }

    private void show_custom_game_screen ()
    {
        is_new_game_screen = false;
        custom_game_screen.show ();
        minefield_aspect.hide ();
        new_game_screen.hide ();
    }

    private bool can_start_new_game ()
    {
        if (minefield != null && minefield.n_cleared > 0 && !minefield.exploded && !minefield.is_complete)
        {
            var was_paused = minefield.paused;
            minefield.paused = true;

            var dialog = new Gtk.MessageDialog (window, Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, "%s", _("Do you want to start a new game?"));
            dialog.secondary_text = (_("If you start a new game, your current progress will be lost."));
            dialog.add_buttons (_("Keep Current Game"), Gtk.ResponseType.DELETE_EVENT,
                                _("Start New Game"), Gtk.ResponseType.ACCEPT,
                                null);
            var result = dialog.run ();
            dialog.destroy ();
            if (result != Gtk.ResponseType.ACCEPT)
            {
                minefield.paused = was_paused;
                return false;
            }
        }
        return true;
    }

    private void show_new_game_screen ()
    {
        if (is_new_game_screen)
            return;

        if (minefield != null)
        {
            minefield.paused = false;
            pause_requested = false;
            SignalHandler.disconnect_by_func (minefield, null, this);
        }
        minefield = null;

        is_new_game_screen = true;
        custom_game_screen.hide ();
        minefield_aspect.hide ();
        new_game_screen.show ();
        window.resize (window_width, window_height);

        new_game_button.show ();

        new_game_action.set_enabled (false);
        repeat_size_action.set_enabled (false);
        pause_action.set_enabled (false);
        buttons_box.hide ();
    }

    private void start_game ()
    {
        is_new_game_screen = false;
        custom_game_screen.hide ();
        window_skip_configure = true;
        minefield_aspect.show ();
        minefield_view.has_focus = true;
        new_game_screen.hide ();
        play_pause_button.hide ();
        replay_button.hide ();
        new_game_button.hide ();
        high_scores_button.hide ();
        buttons_box.show ();

        tick_cb ();

        int x, y, n;
        switch (settings.get_int (KEY_MODE))
        {
        case 0:
            x = 8;
            y = 8;
            n = 10;
            break;
        case 1:
            x = 16;
            y = 16;
            n = 40;
            break;
        case 2:
            x = 30;
            y = 16;
            n = 99;
            break;
        default:
        case 3:
            x = settings.get_int (KEY_XSIZE).clamp (XSIZE_MIN, XSIZE_MAX);
            y = settings.get_int (KEY_YSIZE).clamp (YSIZE_MIN, YSIZE_MAX);
            n = settings.get_int (KEY_NMINES).clamp (1, x * y - 10);
            break;
        }

        if (minefield != null)
            SignalHandler.disconnect_by_func (minefield, null, this);
        minefield = new Minefield (x, y, n);
        minefield.marks_changed.connect (marks_changed_cb);
        minefield.explode.connect (explode_cb);
        minefield.cleared.connect (cleared_cb);
        minefield.tick.connect (tick_cb);
        minefield.paused_changed.connect (paused_changed_cb);
        minefield.clock_started.connect (clock_started_cb);

        minefield_aspect.ratio = (float)x / y;
        minefield_view.minefield = minefield;

        update_flag_label ();

        new_game_action.set_enabled (true);
        repeat_size_action.set_enabled (true);
        pause_action.set_enabled (true);

        minefield.paused = false;
        pause_requested = false;
    }

    private void new_game_cb ()
    {
        if (can_start_new_game ())
            show_new_game_screen ();
    }

    private void repeat_size_cb ()
    {
        if (can_start_new_game ())
            start_game ();
    }

    private void toggle_pause_cb ()
    {
        if (minefield.paused && !pause_requested)
        {
            pause_requested = true;
        }
        else
        {
            minefield.paused = !minefield.paused;
            pause_requested = minefield.paused;
        }
    }

    private void paused_changed_cb ()
    {
        if (minefield.paused)
            display_unpause_button ();
        else if (minefield.elapsed > 0)
            display_pause_button ();
        paused_box.visible = minefield.paused;
    }

    private void marks_changed_cb (Minefield minefield)
    {
        update_flag_label ();
    }

    private void explode_cb (Minefield minefield)
    {
        new_game_button.show ();
        replay_button.show ();
        high_scores_button.show ();
        pause_action.set_enabled (false);
        play_pause_button.hide ();
    }

    private void cleared_cb (Minefield minefield)
    {
        var date = new DateTime.now_local ();
        var duration = (uint) (minefield.elapsed + 0.5);
        var entry = new HistoryEntry (date, minefield.width, minefield.height, minefield.n_mines, duration);
        history.add (entry);
        history.save ();

        if (show_scores (entry, true) == Gtk.ResponseType.OK)
            show_new_game_screen ();
        else
        {
            new_game_button.show ();
            replay_button.show ();
            high_scores_button.show ();
            pause_action.set_enabled (false);
            play_pause_button.hide ();
        }
    }

    private void clock_started_cb ()
    {
        display_pause_button ();
    }

    private void tick_cb ()
    {
        var elapsed = 0;
        if (minefield != null)
            elapsed = (int) (minefield.elapsed + 0.5);
        var hours = elapsed / 3600;
        var minutes = (elapsed - hours * 3600) / 60;
        var seconds = elapsed - hours * 3600 - minutes * 60;
        if (hours > 0)
            clock_label.set_text ("%02d:%02d:%02d".printf (hours, minutes, seconds));
        else
            clock_label.set_text ("%02d:%02d".printf (minutes, seconds));
    }

    private void about_cb ()
    {
        string[] authors =
        {
            _("Main game:"),
            "Szekeres Istvan (Pista)",
            "Robert Ancell",
            "",
            _("Score:"),
            "Horacio J. Peña",
            "",
            _("Resizing and SVG support:"),
            "Steve Chaplin",
            "Callum McKenzie",
            null
        };

        string[] artists =
        {
            "Richard Hoelscher",
            null
        };

        string[] documenters =
        {
            "Ekaterina Gerasimova",
            null
        };

        Gtk.show_about_dialog (window,
                               "name", _("Mines"),
                               "version", VERSION,
                               "comments",
                               _("Clear explosive mines off the board\n\nMines is a part of GNOME Games."),
                               "copyright",
                               "Copyright © 1997–2008 Free Software Foundation, Inc.",
                               "license-type", Gtk.License.GPL_2_0,
                               "authors", authors,
                               "artists", artists,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "gnome-mines", "website",
                               "https://wiki.gnome.org/Apps/Mines",
                               null);
    }

    private float percent_mines ()
    {
        return 100.0f * (float) settings.get_int (KEY_NMINES) / (settings.get_int (KEY_XSIZE) * settings.get_int (KEY_YSIZE));
    }

    private void set_mines_limit ()
    {
        var size = settings.get_int (KEY_XSIZE) * settings.get_int (KEY_YSIZE);
        var max_mines = (int) Math.round (100.0f * (float) (size - 10) / size);
        var min_mines = int.max (1, (int) Math.round (100.0f / size));
        mines_spin.set_range (min_mines, max_mines);
        mines_spin.set_value ((int) Math.round (percent_mines ()));
    }

    private void xsize_spin_cb (Gtk.SpinButton spin)
    {
        var xsize = spin.get_value_as_int ();        
        if (xsize == settings.get_int (KEY_XSIZE))
            return;

        settings.set_int (KEY_XSIZE, xsize);
        set_mines_limit ();
    }

    private void ysize_spin_cb (Gtk.SpinButton spin)
    {
        var ysize = spin.get_value_as_int ();        
        if (ysize == settings.get_int (KEY_YSIZE))
            return;

        settings.set_int (KEY_YSIZE, ysize);
        set_mines_limit ();
    }

    private void mines_spin_cb (Gtk.SpinButton spin)
    {
        if (Math.fabs (percent_mines () - spin.get_value ()) <= 0.5f)
            return;

        settings.set_int (KEY_NMINES,
                          (int) Math.round (spin.get_value () * (settings.get_int (KEY_XSIZE) * settings.get_int (KEY_YSIZE)) / 100.0f));
    }
    
    private void set_mode (int mode)
    {
        if (mode != settings.get_int (KEY_MODE))
            settings.set_int (KEY_MODE, mode);

        start_game ();
    }

    private void small_size_clicked_cb ()
    {
        set_mode (0);
    }

    private void medium_size_clicked_cb ()
    {
        set_mode (1);
    }

    private void large_size_clicked_cb ()
    {
        set_mode (2);
    }

    private void custom_size_clicked_cb ()
    {
        set_mode (3);
    }

    private void help_cb ()
    {
        try
        {
            Gtk.show_uri (window.get_screen (), "help:gnome-mines", Gtk.get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Failed to show help: %s", e.message);
        }
    }

    private void display_pause_button ()
    {
        replay_button.hide ();
        new_game_button.hide ();

        play_pause_button.show ();
        play_pause_button.action_name = "app.pause";
        play_pause_button.label = _("_Pause");
        var label = (Gtk.Label)play_pause_button.get_child ();
        label.margin = 12;
        label.margin_left = 24;
        label.margin_right = 24;
    }

    private void display_unpause_button ()
    {
        replay_button.show ();
        new_game_button.show ();

        play_pause_button.show ();
        play_pause_button.action_name = "app.pause";
        play_pause_button.label = _("_Resume");
        var label = (Gtk.Label)play_pause_button.get_child ();
        label.margin = 12;
        label.margin_left = 24;
        label.margin_right = 24;
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        var context = new OptionContext (null);
        context.set_translation_domain (GETTEXT_PACKAGE);
        context.add_group (Gtk.get_option_group (true));

        try
        {
            context.parse (ref args);
        }
        catch (Error e)
        {
            stderr.printf ("%s\n", e.message);
            return Posix.EXIT_FAILURE;
        }

        var app = new Mines ();
        return app.run ();
    }
}
