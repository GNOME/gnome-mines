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
    private const string KEY_USE_QUESTION_MARKS = "use-question-marks";
    private const string KEY_USE_OVERMINE_WARNING = "use-overmine-warning";
    private const string KEY_USE_AUTOFLAG = "use-autoflag";
    private const string KEY_USE_NUMBER_BORDER = "use-number-border";

    /* Faces for new game button */
    private Gtk.ToolButton face_button;
    private Gtk.Image win_face_image;
    private Gtk.Image sad_face_image;
    private Gtk.Image smile_face_image;
    private Gtk.Image cool_face_image;
    private Gtk.Image worried_face_image;

    private Gtk.ToolButton fullscreen_button;
    private Gtk.ToolButton pause_button;

    private Menu app_main_menu;

    /* Main window */
    private Gtk.Window window;
    private int window_width;
    private int window_height;
    private bool is_fullscreen;
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

    private Gtk.Dialog? pref_dialog = null;
    private Gtk.Label flag_label;
    private Gtk.SpinButton n_mines_spin;
    private Gtk.Label clock_label;
    private SimpleAction new_game_action;
    private SimpleAction repeat_size_action;
    private SimpleAction pause_action;
    private SimpleAction hint_action;
    private Gtk.AspectFrame new_game_screen;
    private Gtk.AspectFrame custom_game_screen;
    private bool is_new_game_screen;

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",      new_game_cb                                            },
        { "repeat-size",   repeat_size_cb                                         },
        { "hint",          hint_cb                                                },
        { "pause",         toggle_pause_cb                                        },
        { "fullscreen",    fullscreen_cb                                          },
        { "scores",        scores_cb                                              },
        { "preferences",   preferences_cb                                         },
        { "quit",          quit_cb                                                },
        { "help",          help_cb                                                },
        { "about",         about_cb                                               }
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

        Gtk.Window.set_default_icon_name ("gnome-mines");

        add_action_entries (action_entries, this);
        new_game_action = lookup_action ("new-game") as SimpleAction;
        new_game_action.set_enabled (false);
        repeat_size_action = lookup_action ("repeat-size") as SimpleAction;
        repeat_size_action.set_enabled (false);
        hint_action = lookup_action ("hint") as SimpleAction;
        hint_action.set_enabled (false);
        pause_action = lookup_action ("pause") as SimpleAction;
        pause_action.set_enabled (false);

        var menu = new Menu ();
        app_main_menu = new Menu ();
        menu.append_section (null, app_main_menu);
        app_main_menu.append (_("_New Game"), "app.new-game");
        app_main_menu.append (_("_Replay Size"), "app.repeat-size");
        app_main_menu.append (_("_Hint"), "app.hint");
        app_main_menu.append (_("_Pause"), "app.pause");
        app_main_menu.append (_("_Fullscreen"), "app.fullscreen");
        app_main_menu.append (_("_Scores"), "app.scores");
        app_main_menu.append (_("_Preferences"), "app.preferences");
        var section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Help"), "app.help");
        section.append (_("_About"), "app.about");
        section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Quit"), "app.quit");
        set_app_menu (menu);

        add_accelerator ("<Primary>n", "app.new-game", null);
        add_accelerator ("<Primary>r", "app.repeat-size", null);
        add_accelerator ("Pause", "app.pause", null);
        add_accelerator ("F11", "app.fullscreen", null);
        add_accelerator ("F1", "app.help", null);
        add_accelerator ("<Primary>w", "app.quit", null);
        add_accelerator ("<Primary>q", "app.quit", null);

        window = new Gtk.ApplicationWindow (this);
        window.title = _("Mines");
        window.configure_event.connect (window_configure_event_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.focus_out_event.connect (window_focus_out_event_cb);
        window.focus_in_event.connect (window_focus_in_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));        
        if (settings.get_boolean ("window-is-fullscreen"))
            window.fullscreen ();
        else if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        add_window (window);

        var main_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        window.add (main_vbox);
        main_vbox.show ();

        var status_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        status_box.show ();

        /* show the numbers of total and remaining mines */
        flag_label = new Gtk.Label ("");
        flag_label.show ();

        status_box.pack_start (flag_label, false, false, 0);

        /* game clock */
        clock_label = new Gtk.Label ("");
        clock_label.show ();
        status_box.pack_start (clock_label, false, false, 0);

        /* create fancy faces */
        win_face_image = load_face_image ("face-win.svg");
        sad_face_image = load_face_image ("face-sad.svg");
        smile_face_image = load_face_image ("face-smile.svg");
        cool_face_image = load_face_image ("face-cool.svg");
        worried_face_image = load_face_image ("face-worried.svg");

        var toolbar = new Gtk.Toolbar ();
        toolbar.show ();
        toolbar.show_arrow = false;
        toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);

        face_button = new Gtk.ToolButton (null, _("_New"));
        face_button.use_underline = true;
        face_button.icon_name = "document-new";
        face_button.action_name = "app.new-game";
        face_button.is_important = true;
        set_face_image (smile_face_image);
        face_button.show ();
        toolbar.insert (face_button, -1);

        var hint_button = new Gtk.ToolButton (null, _("Hint"));
        hint_button.use_underline = true;
        hint_button.icon_name = "dialog-information";
        hint_button.action_name = "app.hint";
        hint_button.is_important = true;
        hint_button.show ();
        toolbar.insert (hint_button, -1);

        pause_button = new Gtk.ToolButton (null, _("_Pause"));
        pause_button.icon_name = "media-playback-pause";
        pause_button.use_underline = true;
        pause_button.action_name = "app.pause";
        pause_button.show ();
        toolbar.insert (pause_button, -1);

        fullscreen_button = new Gtk.ToolButton (null, _("_Fullscreen"));
        fullscreen_button.icon_name = "view-fullscreen";
        fullscreen_button.use_underline = true;
        fullscreen_button.action_name = "app.fullscreen";
        fullscreen_button.show ();
        toolbar.insert (fullscreen_button, -1);

        var status_alignment = new Gtk.Alignment (1.0f, 0.5f, 0.0f, 0.0f);
        status_alignment.add (status_box);
        status_alignment.show ();

        var status_item = new Gtk.ToolItem ();
        status_item.set_expand (true);
        status_item.add (status_alignment);
        status_item.show ();

        toolbar.insert (status_item, -1);
        main_vbox.pack_start (toolbar, false, false, 0);

        var view_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        view_box.border_width = 3;
        view_box.show ();
        main_vbox.pack_start (view_box, true, true, 0);

        minefield_view = new MinefieldView ();
        minefield_view.set_use_question_marks (settings.get_boolean (KEY_USE_QUESTION_MARKS));
        minefield_view.set_use_overmine_warning (settings.get_boolean (KEY_USE_OVERMINE_WARNING));
        minefield_view.set_use_autoflag (settings.get_boolean (KEY_USE_AUTOFLAG));
        minefield_view.set_use_number_border (settings.get_boolean (KEY_USE_NUMBER_BORDER));
        minefield_view.button_press_event.connect (view_button_press_event);
        minefield_view.look.connect (look_cb);
        minefield_view.unlook.connect (unlook_cb);
        view_box.pack_start (minefield_view, true, true, 0);

        /* Initialize New Game Screen */
        startup_new_game_screen ();
        view_box.pack_start (new_game_screen, true, true, 0);

        /* Initialize Custom Game Screen */
        startup_custom_game_screen ();
        view_box.pack_start (custom_game_screen, true, false);

        tick_cb ();

        history = new History (Path.build_filename (Environment.get_user_data_dir (), "gnome-mines", "history"));
        history.load ();
    }

    private void startup_new_game_screen ()
    {
        new_game_screen = new Gtk.AspectFrame (_("Field Size"), 0.5f, 0.5f, 1.0f, false);
        new_game_screen.set_shadow_type (Gtk.ShadowType.NONE);
        new_game_screen.set_size_request (200, 200);

        var new_game_grid = new Gtk.Grid ();
        new_game_grid.column_homogeneous = true;
        new_game_grid.column_spacing = 0;
        new_game_grid.row_homogeneous = true;
        new_game_grid.row_spacing = 0;
        new_game_screen.add (new_game_grid);

        var button = new Gtk.Button ();
        button.clicked.connect (small_size_clicked_cb);
        new_game_grid.attach (button, 0, 0, 1, 1);

        var label = new Gtk.Label (null);
        label.set_markup (make_minefield_description ("#0000ff", 8, 8, 10));
        label.set_justify (Gtk.Justification.CENTER);
        button.add (label);

        button = new Gtk.Button ();
        button.clicked.connect (medium_size_clicked_cb);
        new_game_grid.attach (button, 1, 0, 1, 1);

        label = new Gtk.Label (null);
        label.set_markup (make_minefield_description ("#00a000", 16, 16, 40));
        label.set_justify (Gtk.Justification.CENTER);
        button.add (label);

        button = new Gtk.Button ();
        button.clicked.connect (large_size_clicked_cb);
        new_game_grid.attach (button, 0, 1, 1, 1);

        label = new Gtk.Label (null);
        label.set_markup (make_minefield_description ("#ff0000", 30, 16, 99));
        label.set_justify (Gtk.Justification.CENTER);
        button.add (label);

        button = new Gtk.Button ();
        button.clicked.connect (show_custom_game_screen);
        new_game_grid.attach (button, 1, 1, 1, 1);

        label = new Gtk.Label (null);
        label.set_markup_with_mnemonic ("<span fgcolor='#00007f'><span size='xx-large' weight='heavy'>?</span>\n" + dpgettext2 (null, "board size", _("Custom")) + "</span>");
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

        var label = new Gtk.Label.with_mnemonic (_("H_orizontal:"));
        label.set_alignment (0, 0.5f);
        custom_game_grid.attach (label, 0, 0, 1, 1);

        var field_width_entry = new Gtk.SpinButton.with_range (XSIZE_MIN, XSIZE_MAX, 1);
        field_width_entry.value_changed.connect (xsize_spin_cb);
        field_width_entry.set_value (settings.get_int (KEY_XSIZE));
        custom_game_grid.attach (field_width_entry, 1, 0, 1, 1);
        label.set_mnemonic_widget (field_width_entry);

        label = new Gtk.Label.with_mnemonic (_("_Vertical:"));
        label.set_alignment (0, 0.5f);
        custom_game_grid.attach (label, 0, 1, 1, 1);

        var field_height_entry = new Gtk.SpinButton.with_range (YSIZE_MIN, YSIZE_MAX, 1);
        field_height_entry.value_changed.connect (ysize_spin_cb);
        field_height_entry.set_value (settings.get_int (KEY_YSIZE));
        custom_game_grid.attach (field_height_entry, 1, 1, 1, 1);
        label.set_mnemonic_widget (field_height_entry);

        label = new Gtk.Label.with_mnemonic (_("_Number of mines:"));
        label.set_alignment (0, 0.5f);
        custom_game_grid.attach (label, 0, 2, 1, 1);

        n_mines_spin = new Gtk.SpinButton.with_range (1, XSIZE_MAX * YSIZE_MAX, 1);
        n_mines_spin.value_changed.connect (n_mines_spin_cb);
        n_mines_spin.set_value (settings.get_int (KEY_NMINES));
        custom_game_grid.attach (n_mines_spin, 1, 2, 1, 1);
        set_n_mines_limit ();
        label.set_mnemonic_widget (n_mines_spin);

        var button_grid = new Gtk.Grid ();
        button_grid.column_homogeneous = false;
        button_grid.column_spacing = 5;
        custom_game_grid.attach (button_grid, 0, 3, 2, 1);

        var button = new Gtk.Button.from_stock (Gtk.Stock.CANCEL);
        button.expand = true;
        button.clicked.connect (show_new_game_screen);
        button_grid.attach (button, 0, 0, 1, 1);

        button = new Gtk.Button.with_mnemonic (_("_Play Game"));
        button.expand = true;
        button.set_image (new Gtk.Image.from_stock (Gtk.Stock.GO_FORWARD, Gtk.IconSize.BUTTON));
        button.clicked.connect (custom_size_clicked_cb);
        button_grid.attach (button, 1, 0, 1, 1);

        custom_game_screen.show_all ();
        custom_game_screen.hide ();
    }

    private bool window_configure_event_cb (Gdk.EventConfigure event)
    {
        if (!is_maximized && !is_fullscreen && !window_skip_configure)
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
        if ((event.changed_mask & Gdk.WindowState.FULLSCREEN) != 0)
        {
            is_fullscreen = (event.new_window_state & Gdk.WindowState.FULLSCREEN) != 0;
            if (is_fullscreen)
            {
                fullscreen_button.label = _("_Leave Fullscreen");
                fullscreen_button.icon_name = "view-restore";
            }
            else
            {
                fullscreen_button.label = _("_Fullscreen");            
                fullscreen_button.icon_name = "view-fullscreen";
            }
        }
        return false;
    }

    private bool window_focus_out_event_cb (Gdk.EventFocus event)
    {
        if (minefield != null)
            minefield.paused = true;

        return false;
    }

    private bool window_focus_in_event_cb (Gdk.EventFocus event)
    {
        if (minefield != null && !pause_requested)
            minefield.paused = false;

        return false;
    }

    private string make_minefield_description (string color, int width, int height, int n_mines)
    {
        var size_label = "%d × %d".printf (width, height);
        var mines_label = ngettext ("<b>%d</b> mine", "<b>%d</b> mines", n_mines).printf (n_mines);
        return "<span fgcolor='%s'><span size='x-large' weight='ultrabold'>%s</span>\n%s</span>".printf (color, size_label, mines_label);
    }

    public void start ()
    {
        window.show ();
        show_new_game_screen ();
        set_face_image (smile_face_image);
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        /* Save window state */
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", is_maximized);
        settings.set_boolean ("window-is-fullscreen", is_fullscreen);
    }

    public override void activate ()
    {
        window.show ();
    }

    private Gtk.Image load_face_image (string name)
    {
        var image = new Gtk.Image ();
        var filename = Path.build_filename (DATA_DIRECTORY, name);

        if (filename != null)
            image.set_from_file (filename);

        image.show ();

        return image;
    }

    private void set_face_image (Gtk.Image face_image)
    {
        face_button.set_icon_widget (face_image);
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
        flag_label.set_text (_("Flags: %u/%u").printf (minefield.n_flags, minefield.n_mines));
    }

    private int show_scores (HistoryEntry? selected_entry = null, bool show_quit = false)
    {
        var dialog = new ScoreDialog (history, selected_entry, show_quit);
        dialog.modal = true;
        dialog.transient_for = window;

        var result = dialog.run ();
        dialog.destroy ();

        return result;
    }

    private void fullscreen_cb ()
    {
        if (is_fullscreen)
            window.unfullscreen ();
        else
            window.fullscreen ();
    }

    private void scores_cb ()
    {
        show_scores ();
    }

    private void show_custom_game_screen ()
    {
        is_new_game_screen = false;
        custom_game_screen.show ();
        minefield_view.hide ();
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
        minefield_view.hide ();
        new_game_screen.show ();
        flag_label.set_text("");
        set_face_image (smile_face_image);
        window.resize (window_width, window_height);

        new_game_action.set_enabled (false);
        repeat_size_action.set_enabled (false);
        hint_action.set_enabled (false);
        pause_action.set_enabled (false);
    }

    private void start_game ()
    {
        is_new_game_screen = false;
        custom_game_screen.hide ();
        window_skip_configure = true;
        minefield_view.show ();
        minefield_view.has_focus = true;
        new_game_screen.hide ();

        set_face_image (smile_face_image);

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

        minefield_view.minefield = minefield;

        update_flag_label ();

        new_game_action.set_enabled (true);
        repeat_size_action.set_enabled (true);
        hint_action.set_enabled (true);
        pause_action.set_enabled (true);

        minefield.paused = false;
        pause_requested = false;
    }

    private void hint_cb ()
    {
        minefield.hint ();
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
        /* KLUDGE: This is a very expensive way to change a label,
         *  but it doesn't seem we have much of an option, lets just
         *  hope the C compiler can optimise this.
         */
        app_main_menu.remove (3);  // Remove pause/resume menuitem

        if (minefield.paused)
        {
            hint_action.set_enabled (false);
            pause_button.icon_name = "media-playback-start";
            pause_button.label = _("Res_ume");
            if (pause_requested)
                app_main_menu.insert (3, _("Res_ume"), "app.pause");
            else
                app_main_menu.insert (3, _("_Pause"), "app.pause");
        }
        else
        {
            hint_action.set_enabled (true);
            pause_button.icon_name = "media-playback-pause";
            pause_button.label = _("_Pause");
            app_main_menu.insert (3, _("_Pause"), "app.pause");
        }
    }

    private void marks_changed_cb (Minefield minefield)
    {
        update_flag_label ();
    }

    private void explode_cb (Minefield minefield)
    {
        set_face_image (sad_face_image);
        hint_action.set_enabled (false);
        pause_action.set_enabled (false);
    }

    private void cleared_cb (Minefield minefield)
    {
        set_face_image (win_face_image);

        var date = new DateTime.now_local ();
        var duration = (uint) (minefield.elapsed + 0.5);
        var entry = new HistoryEntry (date, minefield.width, minefield.height, minefield.n_mines, duration);
        history.add (entry);
        history.save ();

        if (show_scores (entry, true) == Gtk.ResponseType.CLOSE)
            window.destroy ();
        else
            show_new_game_screen ();
    }

    private void tick_cb ()
    {
        var elapsed = 0;
        if (minefield != null)
            elapsed = (int) (minefield.elapsed + 0.5);
        var hours = elapsed / 3600;
        var minutes = (elapsed - hours * 3600) / 60;
        var seconds = elapsed - hours * 3600 - minutes * 60;
        clock_label.set_text ("%s: %02d:%02d:%02d".printf (_("Time"), hours, minutes, seconds));
    }

    private void look_cb (MinefieldView minefield_view)
    {
        set_face_image (worried_face_image);
    }

    private void unlook_cb (MinefieldView minefield_view)
    {
        set_face_image (cool_face_image);
    }

    private void about_cb ()
    {
        string[] authors =
        {
            _("Main game:"),
            "Pista",
            "Szekeres Istvan",
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
            _("Faces:"),
            "tigert",
            "Lapo Calamandrei and Ulisse Perusin",
            "",
            _("Graphics:"),
            "Richard Hoelscher",
            null
        };

        string[] documenters =
        {
            "Callum McKenzie",
            null
        };

        var license = "Mines is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.\n\nMines is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.\n\nYou should have received a copy of the GNU General Public License along with Mines; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA";

        Gtk.show_about_dialog (window,
                               "name", _("Mines"),
                               "version", VERSION,
                               "comments",
                               _("The popular logic puzzle minesweeper. Clear mines from a board using hints from squares you have already uncovered.\n\nMines is a part of GNOME Games."),
                               "copyright",
                               "Copyright \xc2\xa9 1997-2008 Free Software Foundation, Inc.",
                               "license", license,
                               "authors", authors,
                               "artists", artists,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "gnome-mines", "website",
                               "http://www.gnome.org/projects/gnome-games/",
                               "website-label", _("GNOME Games web site"),
                               "wrap-license", true, null);
    }

    private void set_n_mines_limit ()
    {
        /* Fix up the maximum number of mines so that there is always at least
         * ten free spaces. Nine are so we can clear at least the immediate
         * eight neighbours at the start and one more so the game isn't over
         * immediately. */
        var max_mines = settings.get_int (KEY_XSIZE) * settings.get_int (KEY_YSIZE) - 10;
        if (settings.get_int (KEY_NMINES) > max_mines)
        {
            settings.set_int (KEY_NMINES, max_mines);
            n_mines_spin.set_value (max_mines);
        }
        n_mines_spin.set_range (1, max_mines);
    }

    private void xsize_spin_cb (Gtk.SpinButton spin)
    {
        var xsize = spin.get_value_as_int ();        
        if (xsize == settings.get_int (KEY_XSIZE))
            return;

        settings.set_int (KEY_XSIZE, xsize);
        set_n_mines_limit ();
    }

    private void ysize_spin_cb (Gtk.SpinButton spin)
    {
        var ysize = spin.get_value_as_int ();        
        if (ysize == settings.get_int (KEY_YSIZE))
            return;

        settings.set_int (KEY_YSIZE, ysize);
        set_n_mines_limit ();
    }

    private void n_mines_spin_cb (Gtk.SpinButton spin)
    {
        var n_mines = spin.get_value_as_int ();
        if (n_mines == settings.get_int (KEY_NMINES))
            return;

        settings.set_int (KEY_NMINES, n_mines);
    }

    private void use_question_toggle_cb (Gtk.ToggleButton button)
    {
        var use_question_marks = button.get_active ();
        settings.set_boolean (KEY_USE_QUESTION_MARKS, use_question_marks);
        minefield_view.set_use_question_marks (use_question_marks);
    }

    private void use_overmine_toggle_cb (Gtk.ToggleButton button)
    {
        var use_overmine_warning = button.get_active ();
        settings.set_boolean (KEY_USE_OVERMINE_WARNING, use_overmine_warning);
        minefield_view.set_use_overmine_warning (use_overmine_warning);
    }

    private void use_number_border_toggle_cb (Gtk.ToggleButton button)
    {
        var use_number_border = button.get_active ();
        settings.set_boolean (KEY_USE_NUMBER_BORDER, use_number_border);
        minefield_view.set_use_number_border (use_number_border);
    }

    private Gtk.Dialog create_preferences ()
    {
        var dialog = new Gtk.Dialog.with_buttons (_("Mines Preferences"),
                                                  window,
                                                  0,
                                                  Gtk.Stock.CLOSE,
                                                  Gtk.ResponseType.CLOSE, null);
        dialog.response.connect (pref_response_cb);
        dialog.delete_event.connect (pref_delete_event_cb);
        dialog.set_border_width (5);
        dialog.set_resizable (false);
        var box = (Gtk.Box) dialog.get_content_area ();

        var grid = new Gtk.Grid ();
        grid.show ();
        grid.border_width = 6;
        grid.set_row_spacing (6);
        grid.set_column_spacing (18);
        box.add (grid);

        var question_toggle = new Gtk.CheckButton.with_mnemonic (_("_Use \"I'm not sure\" flags"));
        question_toggle.show ();
        question_toggle.toggled.connect (use_question_toggle_cb);
        question_toggle.set_active (settings.get_boolean (KEY_USE_QUESTION_MARKS));
        grid.attach (question_toggle, 0, 0, 1, 1);

        var overmine_toggle = new Gtk.CheckButton.with_mnemonic (_("_Warn if too many flags have been placed"));
        overmine_toggle.show ();
        overmine_toggle.toggled.connect (use_overmine_toggle_cb);
        overmine_toggle.set_active (settings.get_boolean (KEY_USE_OVERMINE_WARNING));
        grid.attach (overmine_toggle, 0, 1, 1, 1);

        var border_toggle = new Gtk.CheckButton.with_mnemonic (_("_Display numbers with border"));
        border_toggle.show ();
        border_toggle.toggled.connect (use_number_border_toggle_cb);
        border_toggle.set_active (settings.get_boolean (KEY_USE_NUMBER_BORDER));
        grid.attach (border_toggle, 0, 2, 1, 1);

        return dialog;
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
    
    private void pref_response_cb (Gtk.Dialog dialog, int response_id)
    {
        pref_dialog.hide ();
    }

    private bool pref_delete_event_cb (Gtk.Widget widget, Gdk.EventAny event)
    {
        pref_dialog.hide ();
        return true;
    }

    private void preferences_cb ()
    {
        if (pref_dialog == null)
            pref_dialog = create_preferences ();
        pref_dialog.present ();
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

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        /* Required if the desktop file does not match the binary */
        Environment.set_prgname ("gnomine");

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

public class ScoreDialog : Gtk.Dialog
{
    private History history;
    private HistoryEntry? selected_entry = null;
    private Gtk.ListStore size_model;
    private Gtk.ListStore score_model;
    private Gtk.ComboBox size_combo;

    public ScoreDialog (History history, HistoryEntry? selected_entry = null, bool show_quit = false)
    {
        this.history = history;
        history.entry_added.connect (entry_added_cb);
        this.selected_entry = selected_entry;

        if (show_quit)
        {
            add_button (Gtk.Stock.QUIT, Gtk.ResponseType.CLOSE);

            var button = add_button (_("New Game"), Gtk.ResponseType.OK);
            button.has_focus = true;
        }
        else
            add_button (Gtk.Stock.OK, Gtk.ResponseType.DELETE_EVENT);
        set_size_request (200, 300);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        vbox.border_width = 6;
        vbox.show ();
        get_content_area ().pack_start (vbox, true, true, 0);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        hbox.show ();
        vbox.pack_start (hbox, false, false, 0);

        var label = new Gtk.Label (_("Size:"));
        label.show ();
        hbox.pack_start (label, false, false, 0);

        size_model = new Gtk.ListStore (4, typeof (string), typeof (int), typeof (int), typeof (int));

        size_combo = new Gtk.ComboBox ();
        size_combo.changed.connect (size_changed_cb);
        size_combo.model = size_model;
        var renderer = new Gtk.CellRendererText ();
        size_combo.pack_start (renderer, true);
        size_combo.add_attribute (renderer, "text", 0);
        size_combo.show ();
        hbox.pack_start (size_combo, true, true, 0);

        var scroll = new Gtk.ScrolledWindow (null, null);
        scroll.shadow_type = Gtk.ShadowType.ETCHED_IN;
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.show ();
        vbox.pack_start (scroll, true, true, 0);

        score_model = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (int));

        var scores = new Gtk.TreeView ();
        renderer = new Gtk.CellRendererText ();
        scores.insert_column_with_attributes (-1, _("Date"), renderer, "text", 0, "weight", 2);
        renderer = new Gtk.CellRendererText ();
        renderer.xalign = 1.0f;
        scores.insert_column_with_attributes (-1, _("Time"), renderer, "text", 1, "weight", 2);
        scores.model = score_model;
        scores.show ();
        scroll.add (scores);

        foreach (var entry in history.entries)
            entry_added_cb (entry);
    }

    public void set_size (uint width, uint height, uint n_mines)
    {
        score_model.clear ();

        var entries = history.entries.copy ();
        entries.sort (compare_entries);

        foreach (var entry in entries)
        {
            if (entry.width != width || entry.height != height || entry.n_mines != n_mines)
                continue;

            var date_label = entry.date.format ("%d/%m/%Y");

            var time_label = "%us".printf (entry.duration);
            if (entry.duration >= 60)
                time_label = "%um %us".printf (entry.duration / 60, entry.duration % 60);

            int weight = Pango.Weight.NORMAL;
            if (entry == selected_entry)
                weight = Pango.Weight.BOLD;

            Gtk.TreeIter iter;
            score_model.append (out iter);
            score_model.set (iter, 0, date_label, 1, time_label, 2, weight);
        }
    }

    private static int compare_entries (HistoryEntry a, HistoryEntry b)
    {
        if (a.width != b.width)
            return (int) a.width - (int) b.width;
        if (a.height != b.height)
            return (int) a.height - (int) b.height;
        if (a.n_mines != b.n_mines)
            return (int) a.n_mines - (int) b.n_mines;
        if (a.duration != b.duration)
            return (int) a.duration - (int) b.duration;
        return a.date.compare (b.date);
    }

    private void size_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;

        int width, height, n_mines;
        combo.model.get (iter, 1, out width, 2, out height, 3, out n_mines);
        set_size ((uint) width, (uint) height, (uint) n_mines);
    }

    private void entry_added_cb (HistoryEntry entry)
    {
        /* Ignore if already have an entry for this */
        Gtk.TreeIter iter;
        var have_size_entry = false;
        if (size_model.get_iter_first (out iter))
        {
            do
            {
                int width, height, n_mines;
                size_model.get (iter, 1, out width, 2, out height, 3, out n_mines);
                if (width == entry.width && height == entry.height && n_mines == entry.n_mines)
                {
                    have_size_entry = true;
                    break;
                }
            } while (size_model.iter_next (ref iter));
        }

        if (!have_size_entry)
        {
            var label = ngettext ("%u × %u, %u mine", "%u × %u, %u mines", entry.n_mines).printf (entry.width, entry.height, entry.n_mines);

            size_model.append (out iter);
            size_model.set (iter, 0, label, 1, entry.width, 2, entry.height, 3, entry.n_mines);
    
            /* Select this entry if don't have any */
            if (size_combo.get_active () == -1)
                size_combo.set_active_iter (iter);

            /* Select this entry if the same category as the selected one */
            if (selected_entry != null && entry.width == selected_entry.width && entry.height == selected_entry.height && entry.n_mines == selected_entry.n_mines)
                size_combo.set_active_iter (iter);
        }
    }
}
