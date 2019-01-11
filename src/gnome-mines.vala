/*
 * Copyright (C) 2011-2012 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
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

    /* For command-line options */
    private static int game_mode = -1;

    /* Shared Settings keys */
    public const string KEY_USE_QUESTION_MARKS = "use-question-marks";
    public const string KEY_USE_OVERMINE_WARNING = "use-overmine-warning";
    public const string KEY_USE_AUTOFLAG = "use-autoflag";
    public const string KEY_THEME = "theme";
    public const string KEY_USE_ANIMATIONS = "use-animations";

    private Gtk.Widget main_screen;
    private Gtk.Button play_pause_button;
    private Gtk.Label play_pause_label;
    private Gtk.Button replay_button;
    private Gtk.Button high_scores_button;
    private Gtk.Button new_game_button;
    private Gtk.AspectFrame minefield_aspect;
    private Gtk.Overlay minefield_overlay;
    private Gtk.Box aspect_child;
    private Gtk.Box buttons_box;
    private Gtk.Box paused_box;
    private Gtk.ScrolledWindow scrolled;
    private Gtk.Stack stack;
    private ThemeSelectorDialog theme_dialog;

    private Gtk.Label clock_label;

    private Menu app_main_menu;

    /* Main window */
    private Gtk.Window window;
    private int window_width;
    private int window_height;
    private bool is_maximized;
    private bool is_tiled;

    /* true when the new game minefield draws once */
    private bool first_draw = false;

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
    private Gtk.Label flag_label;

    private Gtk.SpinButton mines_spin;
    private SimpleAction new_game_action;
    private SimpleAction repeat_size_action;
    private SimpleAction pause_action;
    private SimpleAction[] size_actions = new SimpleAction[4];
    private Gtk.AspectFrame new_game_screen;
    private Gtk.AspectFrame custom_game_screen;
    private Gtk.CssProvider theme_provider;

    private const OptionEntry[] option_entries =
    {
        { "version", 'v', 0, OptionArg.NONE, null, N_("Print release version and exit"), null },
        { "small",  0, 0, OptionArg.NONE, null, N_("Small game"), null },
        { "medium", 0, 0, OptionArg.NONE, null, N_("Medium game"), null },
        { "big",    0, 0, OptionArg.NONE, null, N_("Big game"), null },
        { null }
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
        { "pause",              toggle_pause_cb                             },
        { "scores",             scores_cb                                   },
        { "preferences",        preferences_cb                              },
        { "quit",               quit_cb                                     },
        { "help",               help_cb                                     },
        { "about",              about_cb                                    }
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
            Gtk.IconTheme.get_default ().append_search_path (theme_path);
        } else {
            string[] icon_search_path;
            Gtk.IconTheme.get_default ().get_search_path (out icon_search_path);
            icon_search_path[icon_search_path.length - 1] = theme_path;
            Gtk.IconTheme.get_default ().set_search_path (icon_search_path);
        }

        var theme_css_path = Path.build_filename (theme_path, "theme.css");
        try
        {
            if (is_switch) {
                Gtk.StyleContext.remove_provider_for_screen (Gdk.Screen.get_default (), theme_provider);
            }
            theme_provider = new Gtk.CssProvider ();
            theme_provider.load_from_path (theme_css_path);
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), theme_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (GLib.Error e)
        {
            warning ("Error loading css styles from %s: %s", theme_css_path, e.message);
        }
        if (window != null)
        {
            window.get_window ().invalidate_rect (null, true);
            window.queue_draw ();
        }
        Gtk.StyleContext.reset_widgets (Gdk.Screen.get_default ());
    }

    protected override void startup ()
    {
        base.startup ();

        Environment.set_application_name (_("Mines"));

        settings = new Settings ("org.gnome.Mines");
        settings.delay ();

        if (game_mode != -1)
            settings.set_int (KEY_MODE, game_mode);

        Gtk.Window.set_default_icon_name ("gnome-mines");

        var css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/org/gnome/Mines/gnome-mines.css");

        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        var ui_builder = new Gtk.Builder ();
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

        add_action (settings.create_action (KEY_USE_OVERMINE_WARNING));
        add_action (settings.create_action (KEY_USE_QUESTION_MARKS));

        window = (Gtk.ApplicationWindow) ui_builder.get_object ("main_window");
        window.size_allocate.connect (size_allocate_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.focus_out_event.connect (window_focus_out_event_cb);
        window.focus_in_event.connect (window_focus_in_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        Gtk.Settings.get_default ().gtk_enable_animations = settings.get_boolean ("use-animations");

        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();
        add_window (window);

        var headerbar = new Gtk.HeaderBar ();
        headerbar.show_close_button = true;
        headerbar.set_title (_("Mines"));
        headerbar.show ();
        window.set_titlebar (headerbar);

        bool shell_shows_menubar;
        Gtk.Settings.get_default ().get ("gtk-shell-shows-menubar", out shell_shows_menubar);
        if (!shell_shows_menubar)
        {
            var menu = new Menu ();
            app_main_menu = new Menu ();
            menu.append_section (null, app_main_menu);
            app_main_menu.append (_("_Scores"), "app.scores");
            app_main_menu.append (_("A_ppearance"), "app.preferences");
            var section = new Menu ();
            menu.append_section (null, section);
            section.append (_("_Show Warnings"), "app.%s".printf (KEY_USE_OVERMINE_WARNING));
            section.append (_("_Use Question Flags"), "app.%s".printf (KEY_USE_QUESTION_MARKS));
            section = new Menu ();
            menu.append_section (null, section);
            section.append (_("_Keyboard Shortcuts"), "win.show-help-overlay");
            section.append (_("_Help"), "app.help");
            section.append (_("_About Mines"), "app.about");
            var menu_button = new Gtk.MenuButton ();
            menu_button.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.BUTTON));
            menu_button.show ();
            menu_button.set_menu_model (menu);
            headerbar.pack_end (menu_button);
        }
        else
        {
            var menu = new Menu ();
            var mines_menu = new Menu ();
            menu.append_submenu (_("_Mines"), mines_menu);
            mines_menu.append (_("_New Game"), "app.new-game");
            mines_menu.append (_("_Scores"), "app.scores");
            mines_menu.append (_("A_ppearance"), "app.preferences");
            mines_menu.append (_("_Show Warnings"), "app.%s".printf (KEY_USE_OVERMINE_WARNING));
            mines_menu.append (_("_Use Question Flags"), "app.%s".printf (KEY_USE_QUESTION_MARKS));
            mines_menu.append (_("_Quit"), "app.quit");
            var help_menu = new Menu ();
            menu.append_submenu (_("_Help"), help_menu);
            help_menu.append (_("_Keyboard Shortcuts"), "win.show-help-overlay");
            help_menu.append (_("_Contents"), "app.help");
            help_menu.append (_("_About Mines"), "app.about");
            set_menubar (menu);
        }

        set_accels_for_action ("app.new-game", {"<Primary>n"});
        set_accels_for_action ("app.silent-new-game", {"Escape"});
        set_accels_for_action ("app.repeat-size", {"<Primary>r"});
        set_accels_for_action ("app.small-size", {"1"});
        set_accels_for_action ("app.medium-size", {"2"});
        set_accels_for_action ("app.large-size", {"3"});
        set_accels_for_action ("app.custom-size", {"4"});
        set_accels_for_action ("app.pause", {"Pause"});
        set_accels_for_action ("app.help", {"F1"});
        set_accels_for_action ("app.quit", {"<Primary>q", "<Primary>w"});

        minefield_view = new MinefieldView (settings);
        minefield_view.show ();

        /* Hook a resize on the first minefield draw so that the ratio
           calculation in minefield_aspect.size-allocate runs one more time
           with stable allocation sizes for the current minefield configutation */
        minefield_view.draw.connect ((context, data) => {
            if(!first_draw) {
                minefield_aspect.queue_resize ();
                minefield_view.queue_draw ();
                first_draw = true;
		return true;
            };
            return false;
        });

        stack = (Gtk.Stack) ui_builder.get_object ("stack");

        scrolled = (Gtk.ScrolledWindow) ui_builder.get_object ("scrolled");
        scrolled.add (minefield_view);
        scrolled.show ();

        minefield_overlay = (Gtk.Overlay) ui_builder.get_object ("minefield_overlay");
        minefield_overlay.show ();

        minefield_aspect = (Gtk.AspectFrame) ui_builder.get_object ("minefield_aspect");
        minefield_aspect.show ();

        minefield_aspect.size_allocate.connect ((allocation) => {
             uint width = minefield_view.mine_size * minefield_view.minefield.width;
             width += aspect_child.spacing;
             width += buttons_box.get_allocated_width ();
             float new_ratio = (float) width / (minefield_view.minefield.height * minefield_view.mine_size);
             if (new_ratio != minefield_aspect.ratio) {
                minefield_aspect.ratio = new_ratio;
                first_draw = false;
             };
        });

        paused_box = (Gtk.Box) ui_builder.get_object ("paused_box");
        buttons_box = (Gtk.Box) ui_builder.get_object ("buttons_box");
        aspect_child = (Gtk.Box) ui_builder.get_object ("aspect_child");
        paused_box = (Gtk.Box) ui_builder.get_object ("paused_box");
        paused_box.button_press_event.connect (view_button_press_event);

        minefield_overlay.add_overlay (paused_box);

        main_screen = (Gtk.Widget) ui_builder.get_object ("main_screen");
        main_screen.show_all ();

        /* Initialize New Game Screen */
        startup_new_game_screen (ui_builder);

        /* Initialize Custom Game Screen */
        startup_custom_game_screen (ui_builder);

        context = new Games.Scores.Context.with_importer ("gnome-mines",
                                                          /* Label on the scores dialog */
                                                          _("Minefield:"),
                                                          window,
                                                          create_category_from_key,
                                                          Games.Scores.Style.TIME_LESS_IS_BETTER,
                                                          new Games.Scores.HistoryFileImporter (parse_old_score));

        flag_label = (Gtk.Label) ui_builder.get_object ("flag_label");
        clock_label = (Gtk.Label) ui_builder.get_object ("clock_label");

        play_pause_button = (Gtk.Button) ui_builder.get_object ("play_pause_button");
        play_pause_label = (Gtk.Label) ui_builder.get_object ("play_pause_label");

        high_scores_button = (Gtk.Button) ui_builder.get_object ("high_scores_button");
        replay_button = (Gtk.Button) ui_builder.get_object ("replay_button");
        new_game_button = (Gtk.Button) ui_builder.get_object ("new_game_button");

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

    private void startup_new_game_screen (Gtk.Builder builder)
    {
        new_game_screen =  (Gtk.AspectFrame) builder.get_object ("new_game_screen");

        var button = (Gtk.Button) builder.get_object ("small_size_btn");
        button.clicked.connect (small_size_clicked_cb);

        var label = new Gtk.Label (null);
        label.set_markup (make_minefield_description (8, 8, 10));
        label.set_justify (Gtk.Justification.CENTER);
        button.add (label);

        button = (Gtk.Button) builder.get_object ("medium_size_btn");
        button.clicked.connect (medium_size_clicked_cb);

        label = new Gtk.Label (null);
        label.set_markup (make_minefield_description (16, 16, 40));
        label.set_justify (Gtk.Justification.CENTER);
        button.add (label);

        button = (Gtk.Button) builder.get_object ("large_size_btn");
        button.clicked.connect (large_size_clicked_cb);

        label = new Gtk.Label (null);
        label.set_markup (make_minefield_description (30, 16, 99));
        label.set_justify (Gtk.Justification.CENTER);
        button.add (label);

        button = (Gtk.Button) builder.get_object ("custom_size_btn");
        button.clicked.connect (show_custom_game_screen);

        label = new Gtk.Label (null);
        label.set_markup_with_mnemonic ("<span size='xx-large' weight='heavy'>?</span>\n" + dpgettext2 (null, "board size", _("Custom")));
        label.set_justify (Gtk.Justification.CENTER);
        button.add (label);

        new_game_screen.show_all ();
    }

    private void startup_custom_game_screen (Gtk.Builder builder)
    {
        custom_game_screen =  (Gtk.AspectFrame) builder.get_object ("custom_game_screen");

        var field_width_entry = (Gtk.SpinButton) builder.get_object ("width_spin_btn");
        field_width_entry.set_range (XSIZE_MIN, XSIZE_MAX);
        field_width_entry.value_changed.connect (xsize_spin_cb);
        field_width_entry.set_increments (1, 1);
        field_width_entry.set_value (settings.get_int (KEY_XSIZE));

        var field_height_entry = (Gtk.SpinButton) builder.get_object ("height_spin_btn");
        field_height_entry.set_range (YSIZE_MIN, YSIZE_MAX);
        field_height_entry.value_changed.connect (ysize_spin_cb);
        field_height_entry.set_increments (1, 1);
        field_height_entry.set_value (settings.get_int (KEY_YSIZE));

        mines_spin = (Gtk.SpinButton) builder.get_object ("mines_spin_btn");
        mines_spin.set_range (1, 100);
        mines_spin.set_increments (1, 1);
        mines_spin.value_changed.connect (mines_spin_cb);
        set_mines_limit ();

        var button = (Gtk.Button) builder.get_object ("cancel_btn");
        button.clicked.connect (show_new_game_screen);

        button = (Gtk.Button) builder.get_object ("play_game_btn");
        button.clicked.connect (custom_size_clicked_cb);

        custom_game_screen.show_all ();
    }

    private void size_allocate_cb (Gtk.Allocation allocation)
    {
        if (!is_maximized && !is_tiled && !window_skip_configure)
        {
            window.get_size (out window_width, out window_height);
        }

        window_skip_configure = false;
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        /* We don’t save this state, but track it for saving size allocation */
        if ((event.changed_mask & Gdk.WindowState.TILED) != 0)
            is_tiled = (event.new_window_state & Gdk.WindowState.TILED) != 0;
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
        if (minefield != null && !pause_requested &&
            (theme_dialog == null || theme_dialog.visible == false))
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
        settings.set_boolean (KEY_USE_ANIMATIONS, Gtk.Settings.get_default ().gtk_enable_animations);
        settings.set_boolean ("window-is-maximized", is_maximized);
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
        minefield_view.has_focus = true;

        repeat_size_action.set_enabled (false);
        play_pause_label.label = _("_Pause");
        replay_button.label = _("St_art Over");
        play_pause_button.show ();
        high_scores_button.hide ();

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
            play_pause_label.label = _("_Resume");
        else if (minefield.elapsed > 0)
            play_pause_label.label = _("_Pause");
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
        replay_button.label = _("Play _Again");
        pause_action.set_enabled (false);
        replay_button.sensitive = true;
        repeat_size_action.set_enabled (true);
        play_pause_button.hide ();
        high_scores_button.show ();
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
        play_pause_label.label = _("_Pause");
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
                               _("Clear explosive mines off the board"),
                               "copyright",
                               "Copyright © 1997–2008 Free Software Foundation, Inc.",
                               "license-type", Gtk.License.GPL_3_0,
                               "authors", authors,
                               "artists", artists,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "org.gnome.Mines", "website",
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

        var app = new Mines ();
        return app.run (args);
    }
}
