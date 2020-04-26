/*
 * Copyright (C) 2011-2012 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

using Gtk;

public class Mines : Gtk.Application
{
    /* Settings keys */
    private GLib.Settings settings;
    private const string KEY_XSIZE = "xsize";
    private const int XSIZE_MIN = 4;
    private const int XSIZE_MAX = 100;
    private const string KEY_YSIZE = "ysize";
    private const int YSIZE_MIN = 4;
    private const int YSIZE_MAX = 100;
    private const string KEY_NMINES = "nmines";
    private const string KEY_MODE = "mode";

    /* For command-line options */
    private static int game_mode = -1;

    /* Shared Settings keys */
    public const string KEY_USE_QUESTION_MARKS = "use-question-marks";
    public const string KEY_USE_AUTOFLAG = "use-autoflag";
    public const string KEY_THEME = "theme";
    public const string KEY_USE_ANIMATIONS = "use-animations";

    private Widget main_screen;
    private Box main_screen_layout;
    private Box main_screen_sidebar;
    
    private Button play_pause_button;
    private Image play_pause_image;
    private Button replay_button;
    private Button new_game_button;
    private Overlay minefield_overlay;
    private Box paused_box;
    private Stack stack;
    private ThemeSelectorDialog theme_dialog;

    private Label clock_label;

    private Gtk.MenuButton menu_button;

    private Gdk.Toplevel surface;

    /* Main window */
    private Window window;
    private int window_width;
    private int window_height;
    private bool window_is_maximized;
    private bool window_is_fullscreen;
    private bool window_is_tiled;
    private Orientation current_layout = Orientation.VERTICAL;

    /* true when the user has requested the game to pause. */
    private bool pause_requested;

    /* true when the next configure event should be ignored. */
    private bool window_skip_configure;

    /* Game scores */
    private Games.Scores.Context context;

    /* Minefield being played */
    private Minefield minefield;

    /* Minefield widget */
    private MinefieldView minefield_view;

    /* Game status */
    private Label flag_label;

    private SpinButton mines_spin;
    private SimpleAction new_game_action;
    private SimpleAction repeat_size_action;
    private SimpleAction pause_action;
    private SimpleAction[] size_actions = new SimpleAction[4];
    private AspectFrame new_game_screen;
    private AspectFrame custom_game_screen;
    private CssProvider theme_provider;
    private GestureClick view_click_controller;         // for keeping in memory

    private const OptionEntry[] option_entries =
    {
        { "version", 'v', 0, OptionArg.NONE, null, N_("Print release version and exit"), null },
        { "small",  0, 0, OptionArg.NONE, null, N_("Small game"), null },
        { "medium", 0, 0, OptionArg.NONE, null, N_("Medium game"), null },
        { "big",    0, 0, OptionArg.NONE, null, N_("Big game"), null },
        {}
    };

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",           new_game_cb                                 },
        { "silent-new-game",    silent_new_game_cb                          },
        { "repeat-size",        repeat_size_cb                              },
        { "small-size",         small_size_clicked_cb                       },
        { "medium-size",        medium_size_clicked_cb                      },
        { "large-size",         large_size_clicked_cb                       },
        { "custom-size",        show_custom_game_screen                     },
        { "cancel-custom",      show_new_game_screen                        },
        { "start-custom",       custom_size_clicked_cb                      },
        { "pause",              toggle_pause_cb                             },
        { "scores",             scores_cb                                   },
        { "preferences",        preferences_cb                              },
        { "quit",               quit_cb                                     },
        { "help",               help_cb                                     },
        { "about",              about_cb                                    },
        { "menu",               menu_cb                                     }
    };

    public Mines ()
    {
        Object (application_id: "org.gnome.Mines", flags: ApplicationFlags.FLAGS_NONE);

        add_main_option_entries (option_entries);
    }

    private void set_game_theme (string theme)
    {
        string theme_path = theme;
        bool is_switch = theme_provider != null;

        if (!Path.is_absolute (theme_path)) {
            theme_path = Path.build_path (Path.DIR_SEPARATOR_S, DATA_DIRECTORY, "themes", theme);
        }
        if (!is_switch) {
            IconTheme.get_for_display (Gdk.Display.get_default ()).add_search_path (theme_path);
        } else {
            IconTheme icon_theme = IconTheme.get_for_display (Gdk.Display.get_default ());
            string[] icon_search_path = icon_theme.get_search_path ();
            icon_search_path[icon_search_path.length - 1] = theme_path;
            icon_theme.set_search_path (icon_search_path);
        }

        var theme_css_path = Path.build_filename (theme_path, "theme.css");
        try
        {
            if (is_switch) {
                StyleContext.remove_provider_for_display (Gdk.Display.get_default (), theme_provider);
            }
            theme_provider = new CssProvider ();
            theme_provider.load_from_path (theme_css_path);
            StyleContext.add_provider_for_display (Gdk.Display.get_default (), theme_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (GLib.Error e)
        {
            warning ("Error loading css styles from %s: %s", theme_css_path, e.message);
        }
        if (window != null)
        {
            window.queue_draw ();
        }
    }

    protected override void startup ()
    {
        base.startup ();

        Environment.set_application_name (_("Mines"));
        Environment.set_prgname ("org.gnome.Mines");

        settings = new GLib.Settings ("org.gnome.Mines");

        if (game_mode != -1)
            settings.set_int (KEY_MODE, game_mode);

        Window.set_default_icon_name ("org.gnome.Mines");

        var css_provider = new CssProvider ();
        css_provider.load_from_resource ("/org/gnome/Mines/gnome-mines.css");

        StyleContext.add_provider_for_display (Gdk.Display.get_default (), css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);
        var ui_builder = new Builder ();
        try
        {
            ui_builder.add_from_resource ("/org/gnome/Mines/interface.ui");
        }
        catch (Error e)
        {
            warning ("Could not load game UI: %s", e.message);
        }
        settings.changed[KEY_THEME].connect (() => { set_game_theme (settings.get_string (KEY_THEME)); });
        set_game_theme (settings.get_string (KEY_THEME));

        add_action_entries (action_entries, this);
        new_game_action = lookup_action ("new-game") as SimpleAction;
        new_game_action.set_enabled (true);
        repeat_size_action = lookup_action ("repeat-size") as SimpleAction;
        repeat_size_action.set_enabled (false);
        pause_action = lookup_action ("pause") as SimpleAction;
        pause_action.set_enabled (false);

        size_actions[0] = lookup_action ("small-size") as SimpleAction;
        size_actions[1] = lookup_action ("medium-size") as SimpleAction;
        size_actions[2] = lookup_action ("large-size") as SimpleAction;
        size_actions[3] = lookup_action ("custom-size") as SimpleAction;

        add_action (settings.create_action (KEY_USE_QUESTION_MARKS));

        window = (ApplicationWindow) ui_builder.get_object ("main_window");
        window.size_allocate.connect (size_allocate_cb);
        window.map.connect (init_state_watcher);
        window.notify["is-active"].connect (on_window_focus_change);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        Gtk.Settings.get_default ().gtk_enable_animations = settings.get_boolean ("use-animations");

        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();
        add_window (window);

        menu_button = (Gtk.MenuButton) ui_builder.get_object ("menu_button");

        set_accels_for_action ("app.new-game", {"<Primary>n"});
        set_accels_for_action ("app.silent-new-game", {"Escape"});
        set_accels_for_action ("app.repeat-size", {"<Primary>r"});
        set_accels_for_action ("app.small-size", {"1", "KP_1"});
        set_accels_for_action ("app.medium-size", {"2", "KP_2"});
        set_accels_for_action ("app.large-size", {"3", "KP_3"});
        set_accels_for_action ("app.custom-size", {"4", "KP_4"});
        set_accels_for_action ("app.pause", {"Pause"});
        set_accels_for_action ("app.help", {"F1"});
        set_accels_for_action ("app.quit", {"<Primary>q", "<Primary>w"});
        set_accels_for_action ("app.menu", {"F10"});

        minefield_view = new MinefieldView (settings);

        stack = (Stack) ui_builder.get_object ("stack");

        minefield_overlay = (Overlay) ui_builder.get_object ("minefield_overlay");
        minefield_overlay.add (minefield_view);

        paused_box = (Box) ui_builder.get_object ("paused_box");

        view_click_controller = new GestureClick ();    // only reacts to left-click button
        view_click_controller.pressed.connect (view_button_press_event);
        paused_box.add_controller (view_click_controller);

        minefield_overlay.add_overlay (paused_box);

        main_screen = (Widget) ui_builder.get_object ("main_screen");

        main_screen_layout = (Box) ui_builder.get_object ("main_screen_layout");
        main_screen_sidebar = (Box) ui_builder.get_object ("main_screen_sidebar");

        /* Initialize New Game Screen */
        startup_new_game_screen (ui_builder);

        /* Initialize Custom Game Screen */
        startup_custom_game_screen (ui_builder);

        context = new Games.Scores.Context.with_importer_and_icon_name ("gnome-mines",
                                                                        /* Label on the scores dialog */
                                                                        _("Minefield:"),
                                                                        window,
                                                                        create_category_from_key,
                                                                        Games.Scores.Style.TIME_LESS_IS_BETTER,
                                                                        new Games.Scores.HistoryFileImporter (parse_old_score),
                                                                        "org.gnome.Mines");

        flag_label = (Label) ui_builder.get_object ("flag_label");
        clock_label = (Label) ui_builder.get_object ("clock_label");

        play_pause_button = (Button) ui_builder.get_object ("play_pause_button");
        play_pause_image = (Image) ui_builder.get_object ("play_pause_image");

        replay_button = (Button) ui_builder.get_object ("replay_button");

        new_game_button = (Button) ui_builder.get_object ("new_game_button");
        new_game_button.tooltip_text = translate_and_strip_underlines ("Change _Difficulty");

        if (game_mode != -1)
            start_game ();
    }

    private Games.Scores.Category? create_category_from_key (string key)
    {
        var tokens = key.split ("-");
        if (tokens.length != 3)
            return null;

        var width = int.parse (tokens[0]);
        var height = int.parse (tokens[1]);
        var num_mines = int.parse (tokens[2]);

        if (width <= 0 || height <= 0 || num_mines <= 0)
            return null;

        /* For the scores dialog. First width, then height, then number of mines. */
        return new Games.Scores.Category (key, ngettext ("%d × %d, %d mine",
                                                         "%d × %d, %d mines",
                                                         num_mines).printf (width, height, num_mines));
    }

    private void parse_old_score (string line, out Games.Scores.Score score, out Games.Scores.Category category)
    {
        score = null;
        category = null;

        var tokens = line.split (" ");
        if (tokens.length != 5)
            return;

        var date = Games.Scores.HistoryFileImporter.parse_date (tokens[0]);
        var width = int.parse (tokens[1]);
        var height = int.parse (tokens[2]);
        var num_mines = int.parse (tokens[3]);
        var seconds = int.parse (tokens[4]);

        if (date <= 0 || width <= 0 || height <= 0 || num_mines <= 0 || seconds < 0)
            return;

        score = new Games.Scores.Score (seconds, date);
        category = create_category_from_key (@"$width-$height-$num_mines");
    }

    private void startup_new_game_screen (Builder builder)
    {
        new_game_screen =  (AspectFrame) builder.get_object ("new_game_screen");

        var button = (Button) builder.get_object ("small_size_btn");
        var label = new Label (null);
        label.set_markup (make_minefield_description (8, 8, 10));
        label.set_justify (Justification.CENTER);
        button.add (label);

        button = (Button) builder.get_object ("medium_size_btn");
        label = new Label (null);
        label.set_markup (make_minefield_description (16, 16, 40));
        label.set_justify (Justification.CENTER);
        button.add (label);

        button = (Button) builder.get_object ("large_size_btn");
        label = new Label (null);
        label.set_markup (make_minefield_description (30, 16, 99));
        label.set_justify (Justification.CENTER);
        button.add (label);

        button = (Button) builder.get_object ("custom_size_btn");
        label = new Label (null);
        label.set_markup_with_mnemonic ("<span size='xx-large' weight='heavy'>?</span>\n" + dpgettext2 (null, "board size", _("Custom")));
        label.set_justify (Justification.CENTER);
        button.add (label);
    }

    private void startup_custom_game_screen (Builder builder)
    {
        custom_game_screen = (AspectFrame) builder.get_object ("custom_game_screen");

        var field_width_entry = (SpinButton) builder.get_object ("width_spin_btn");
        field_width_entry.set_range (XSIZE_MIN, XSIZE_MAX);
        field_width_entry.value_changed.connect (xsize_spin_cb);
        field_width_entry.set_increments (1, 1);
        field_width_entry.set_value (settings.get_int (KEY_XSIZE));

        var field_height_entry = (SpinButton) builder.get_object ("height_spin_btn");
        field_height_entry.set_range (YSIZE_MIN, YSIZE_MAX);
        field_height_entry.value_changed.connect (ysize_spin_cb);
        field_height_entry.set_increments (1, 1);
        field_height_entry.set_value (settings.get_int (KEY_YSIZE));

        mines_spin = (SpinButton) builder.get_object ("mines_spin_btn");
        mines_spin.set_range (1, 100);
        mines_spin.set_increments (1, 1);
        mines_spin.value_changed.connect (mines_spin_cb);
        set_mines_limit ();
    }

    private void size_allocate_cb (int width, int height, int baseline)
    {
        int width, height;
        window.get_size (out width, out height);
        if (!window_is_maximized && !window_is_fullscreen && !window_is_tiled && !window_skip_configure)
        {
            window_width = width;
            window_height = height;
        }
        set_main_screen_layout (width > height ? Orientation.HORIZONTAL : Orientation.VERTICAL);

        window_skip_configure = false;
    }

    private void set_main_screen_layout (Orientation orientation)
    {
        if (orientation == current_layout)
            return;

        main_screen_layout.orientation = orientation;
        main_screen_sidebar.orientation = current_layout;

        current_layout = orientation;
    }

    private string translate_and_strip_underlines (string key)
    {
        return _(key).replace ("_", "");
    }

    private const Gdk.ToplevelState tiled_state = Gdk.ToplevelState.TILED
                                                | Gdk.ToplevelState.TOP_TILED
                                                | Gdk.ToplevelState.BOTTOM_TILED
                                                | Gdk.ToplevelState.LEFT_TILED
                                                | Gdk.ToplevelState.RIGHT_TILED;

    private inline void init_state_watcher ()
    {
        Gdk.Surface? nullable_surface = window.get_surface ();
        if (nullable_surface == null || !((!) nullable_surface is Gdk.Toplevel))
            assert_not_reached ();
        surface = (Gdk.Toplevel) (!) nullable_surface;
        surface.notify ["state"].connect (on_window_state_event);
    }

    private inline void on_window_state_event ()
    {
        Gdk.ToplevelState state = surface.get_state ();

        window_is_maximized     = (state & Gdk.ToplevelState.MAXIMIZED)  != 0;
        /* fullscreen: saved as maximized */
        window_is_fullscreen    = (state & Gdk.ToplevelState.FULLSCREEN) != 0;
        /* We don’t save this state, but track it for saving size allocation */
        window_is_tiled         = (state & tiled_state)                  != 0;
    }

    private inline void on_window_focus_change ()
    {
        if (window.is_active)
        {
            if (minefield != null && !pause_requested &&
                (theme_dialog == null || theme_dialog.visible == false))
                minefield.paused = false;
        }
        else
        {
            if (minefield != null && minefield.is_clock_started ())
                minefield.paused = true;
        }
    }

    private string make_minefield_description (int width, int height, int n_mines)
    {
        var size_label = "%d × %d".printf (width, height);
        var mines_label = ngettext ("<b>%d</b> mine", "<b>%d</b> mines", n_mines).printf (n_mines);
        return "<span size='x-large' weight='ultrabold'>%s</span>\n%s".printf (size_label, mines_label);
    }

    public void start ()
    {
        window.present ();
        show_new_game_screen ();
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        /* Save window state */
        settings.delay ();
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean (KEY_USE_ANIMATIONS, Gtk.Settings.get_default ().gtk_enable_animations);
        settings.set_boolean ("window-is-maximized", window_is_maximized || window_is_fullscreen);
        settings.apply ();
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            /* NOTE: Is not translated so can be easily parsed */
            stderr.printf ("%1$s %2$s\n", "gnome-mines", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if (options.contains ("small"))
            game_mode = 0;
        if (options.contains ("medium"))
            game_mode = 1;
        if (options.contains ("big"))
            game_mode = 2;

        /* Activate */
        return -1;
    }

    protected override void activate ()
    {
        window.present ();
    }

    private inline void view_button_press_event (GestureClick _view_click_controller, int n_press, double x, double y)
    {
        /* Cancel pause on click */
        if (!minefield.paused)
            return;

        minefield.paused = false;
        pause_requested = false;
    }

    private void quit_cb ()
    {
        window.destroy ();
    }

    private void update_flag_label ()
    {
        flag_label.set_text ("%u/%u".printf (minefield.n_flags, minefield.n_mines));
    }

    private int show_theme_selector ()
    {
        theme_dialog = new ThemeSelectorDialog (window);

        var result = theme_dialog.run ();
        theme_dialog.destroy ();

        return result;
    }

    private void show_scores ()
    {
        context.run_dialog ();
    }

    private void scores_cb ()
    {
        show_scores ();
    }

    private void preferences_cb ()
    {
        show_theme_selector ();
    }

    private void show_custom_game_screen ()
    {
        if (minefield != null)
            return;
        size_actions_toggle (false);
        stack.visible_child_name = "custom_game";
    }

    private bool can_start_new_game ()
    {
        if (minefield != null && minefield.n_cleared > 0 && !minefield.exploded && !minefield.is_complete)
        {
            var was_paused = minefield.paused;
            minefield.paused = true;

            var dialog = new MessageDialog (window, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.NONE, "%s", _("Do you want to start a new game?"));
            dialog.secondary_text = (_("If you start a new game, your current progress will be lost."));
            dialog.add_buttons (_("Keep Current Game"), ResponseType.DELETE_EVENT,
                                _("Start New Game"),    ResponseType.ACCEPT);
            var result = dialog.run ();
            dialog.destroy ();
            if (result != ResponseType.ACCEPT)
            {
                minefield.paused = was_paused;
                return false;
            }
        }
        return true;
    }

    private void show_new_game_screen ()
    {
        if (stack.visible_child_name == "new_game")
            return;

        if (minefield != null)
        {
            minefield.paused = true;
            pause_requested = false;
            SignalHandler.disconnect_by_func (minefield, null, this);
        }
        minefield = null;

        window.resize (window_width, window_height);

        repeat_size_action.set_enabled (false);
        pause_action.set_enabled (false);

        size_actions_toggle (true);
        stack.visible_child_name = "new_game";
        disable_game_buttons ();
    }

    private void size_actions_toggle (bool enabled)
    {
        for (int i=0; i < size_actions.length; i++)
        {
            size_actions[i].set_enabled (enabled);
        }
    }

    private void start_game ()
    {
        window_skip_configure = true;
        minefield_view.grab_focus ();

        repeat_size_action.set_enabled (false);
        set_play_pause_visuals_unpaused ();
        set_replay_tooltip (_("St_art Over"));
        enable_game_buttons ();

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

        minefield_view.minefield = minefield;

        update_flag_label ();

        minefield.paused = false;
        pause_requested = false;

        stack.visible_child_name = "game";
        pause_action.set_enabled (false);

        tick_cb ();
    }

    private void set_play_pause_visuals_unpaused ()
    {
        set_play_pause_visuals ("media-playback-pause-symbolic", _("_Pause"));
    }

    private void set_play_pause_visuals_paused ()
    {
        set_play_pause_visuals ("media-playback-start-symbolic", _("_Resume"));
    }

    private void set_play_pause_visuals (string icon_name, string tooltip_text)
    {
        play_pause_image.icon_name = icon_name;
        play_pause_button.tooltip_text = translate_and_strip_underlines (tooltip_text);
    }

    private void set_replay_tooltip (string tooltip_text)
    {
        replay_button.tooltip_text = translate_and_strip_underlines (tooltip_text);
    }

    private void enable_game_buttons ()
    {
        set_game_buttons_enabled (true);
    }

    private void disable_game_buttons ()
    {
        set_game_buttons_enabled (false);
    }

    private void set_game_buttons_enabled (bool value)
    {
        new_game_button.visible = value;
        replay_button.visible = value;
        play_pause_button.visible = value;
    }

    private void new_game_cb ()
    {
        if (can_start_new_game ())
            show_new_game_screen ();
    }

    private void silent_new_game_cb ()
    {
        if (minefield == null || minefield.n_cleared == 0)
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
            set_play_pause_visuals_paused ();
        else if (minefield.elapsed > 0)
            set_play_pause_visuals_unpaused ();
        paused_box.visible = minefield.paused;
    }

    private void marks_changed_cb (Minefield minefield)
    {
        update_flag_label ();
    }

    private void explode_cb (Minefield minefield)
    {
        game_ended ();
    }

    private void game_ended ()
    {
        set_replay_tooltip (_("Play _Again"));
        pause_action.set_enabled (false);
        replay_button.sensitive = true;
        repeat_size_action.set_enabled (true);
        play_pause_button.hide ();
    }

    private void cleared_cb (Minefield minefield)
    {
        var duration = (uint) (minefield.elapsed + 0.5);
        string key = minefield.width.to_string () + "-" + minefield.height.to_string () + "-" + minefield.n_mines.to_string ();

        new_game_action.set_enabled (false);
        pause_action.set_enabled (false);
        repeat_size_action.set_enabled (false);

        context.add_score.begin (duration, create_category_from_key (key), null, (object, result) => {
            try
            {
                context.add_score.end (result);
            }
            catch (Error e)
            {
                warning ("%s", e.message);
            }
            new_game_action.set_enabled (true);
            game_ended ();
        });
    }

    private void clock_started_cb ()
    {
        set_play_pause_visuals_unpaused ();
        replay_button.sensitive = true;
        pause_action.set_enabled (true);
        repeat_size_action.set_enabled (true);
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
            clock_label.set_text ("%02d∶\xE2\x80\x8E%02d∶\xE2\x80\x8E%02d".printf (hours, minutes, seconds));
        else
            clock_label.set_text ("%02d∶\xE2\x80\x8E%02d".printf (minutes, seconds));
    }

    private void menu_cb ()
    {
        menu_button.activate();
    }

    private void about_cb ()
    {
        string[] authors =
        {
            _("Main game:"),
            "Szekeres Istvan (Pista)",
            "Robert Ancell",
            "Robert Roth",
            "",
            _("Score:"),
            "Horacio J. Peña",
            "",
            _("Resizing and SVG support:"),
            "Steve Chaplin",
            "Callum McKenzie"
        };

        string[] artists =
        {
            "Richard Hoelscher"
        };

        string[] documenters =
        {
            "Ekaterina Gerasimova"
        };

        show_about_dialog (window,
                           "name", _("Mines"),
                           "version", VERSION,
                           "comments",
                           _("Clear explosive mines off the board"),
                           "copyright",
                           "Copyright © 1997–2008 Free Software Foundation, Inc.",
                           "license-type", License.GPL_3_0,
                           "authors", authors,
                           "artists", artists,
                           "documenters", documenters,
                           "translator-credits", _("translator-credits"),
                           "logo-icon-name", "org.gnome.Mines", "website",
                           "https://wiki.gnome.org/Apps/Mines");
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

    private void xsize_spin_cb (SpinButton spin)
    {
        var xsize = spin.get_value_as_int ();
        if (xsize == settings.get_int (KEY_XSIZE))
            return;

        settings.set_int (KEY_XSIZE, xsize);
        set_mines_limit ();
    }

    private void ysize_spin_cb (SpinButton spin)
    {
        var ysize = spin.get_value_as_int ();
        if (ysize == settings.get_int (KEY_YSIZE))
            return;

        settings.set_int (KEY_YSIZE, ysize);
        set_mines_limit ();
    }

    private void mines_spin_cb (SpinButton spin)
    {
        if (Math.fabs (percent_mines () - spin.get_value ()) <= 0.5f)
            return;

        settings.set_int (KEY_NMINES,
                          (int) Math.round (spin.get_value () * (settings.get_int (KEY_XSIZE) * settings.get_int (KEY_YSIZE)) / 100.0f));
    }

    private void set_mode (int mode)
    {
        if (minefield != null)
            return;

        if (mode != settings.get_int (KEY_MODE))
            settings.set_int (KEY_MODE, mode);

        size_actions_toggle (false);
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
        show_uri (window, "help:gnome-mines", Gdk.CURRENT_TIME);
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        var app = new Mines ();
        return app.run (args);
    }
}
