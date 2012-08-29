public class GnoMine : Gtk.Application
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

    /* Faces for new game button */
    private Gtk.ToolButton face_button;
    private Gtk.Image win_face_image;
    private Gtk.Image sad_face_image;
    private Gtk.Image smile_face_image;
    private Gtk.Image cool_face_image;
    private Gtk.Image worried_face_image;

    private Gtk.ToolButton fullscreen_button;
    private Gtk.ToolButton pause_button;

    /* Main window */
    private Gtk.Window window;
    private int window_width;
    private int window_height;
    private bool is_fullscreen;
    private bool is_maximized;

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

    private const GnomeGamesSupport.ScoresCategory scorecats[] =
    {
        {"Small",  NC_("board size", "Small") },
        {"Medium", NC_("board size", "Medium") },
        {"Large",  NC_("board size", "Large") },
        {"Custom", NC_("board size", "Custom") }
    };

    private GnomeGamesSupport.Scores highscores;

    public GnoMine ()
    {
        Object (application_id: "org.gnome.gnomine", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void startup ()
    {
        base.startup ();

        Environment.set_application_name (_("Mines"));

        settings = new Settings ("org.gnome.gnomine");

        highscores = new GnomeGamesSupport.Scores ("gnomine", scorecats, "board size", null, 0 /* default category */, GnomeGamesSupport.ScoreStyle.TIME_ASCENDING);

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
        var section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_New Game"), "app.new-game");
        section.append (_("_Replay Size"), "app.repeat-size");
        section.append (_("_Hint"), "app.hint");
        section.append (_("_Pause"), "app.pause");
        section.append (_("_Fullscreen"), "app.fullscreen");
        section.append (_("_Scores"), "app.scores");
        section.append (_("_Preferences"), "app.preferences");
        section = new Menu ();
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
        minefield_view.button_press_event.connect (view_button_press_event);
        minefield_view.look.connect (look_cb);
        minefield_view.unlook.connect (unlook_cb);
        view_box.pack_start (minefield_view, true, true, 0);

        /* New game screen */
        new_game_screen = new Gtk.AspectFrame (_("Field Size"), 0.5f, 0.5f, 1.0f, false);
        new_game_screen.set_shadow_type (Gtk.ShadowType.NONE);
        new_game_screen.set_size_request(200, 200);

        var new_game_table = new Gtk.Table (2, 2, true);
        new_game_screen.add (new_game_table);

        var button_small = new Gtk.Button ();
        new_game_table.attach_defaults (button_small, 0, 1, 0, 1);
        button_small.clicked.connect (small_size_clicked_cb);

        var label = new Gtk.Label (null);
        label.set_markup (make_minefield_description ("#0000ff", 8, 8, 10));
        label.set_justify (Gtk.Justification.CENTER);
        button_small.add (label);

        var button_medium = new Gtk.Button ();
        new_game_table.attach_defaults (button_medium, 1, 2, 0, 1);
        button_medium.clicked.connect (medium_size_clicked_cb);

        label = new Gtk.Label (null);
        label.set_markup (make_minefield_description ("#00a000", 16, 16, 40));
        label.set_justify (Gtk.Justification.CENTER);
        button_medium.add (label);

        var button_large = new Gtk.Button ();
        new_game_table.attach_defaults (button_large, 0, 1, 1, 2);
        button_large.clicked.connect (large_size_clicked_cb);

        label = new Gtk.Label (null);
        label.set_markup (make_minefield_description ("#ff0000", 30, 16, 99));
        label.set_justify (Gtk.Justification.CENTER);
        button_large.add (label);

        var button_custom = new Gtk.Button ();
        new_game_table.attach_defaults (button_custom, 1, 2, 1, 2);
        button_custom.clicked.connect (show_custom_game_screen);

        label = new Gtk.Label (null);
        label.set_markup_with_mnemonic ("<span fgcolor='#00007f'><span size='xx-large' weight='heavy'>?</span>\n" + dpgettext2 (null, "board size", "Custom") + "</span>");
        label.set_justify (Gtk.Justification.CENTER);
        button_custom.add (label);

        new_game_screen.show_all ();
        view_box.pack_start (new_game_screen, true, true, 0);

        /* Custom game screen */
        custom_game_screen = new Gtk.AspectFrame ("", 0.5f, 0.5f, 0.0f, true);
        custom_game_screen.set_shadow_type (Gtk.ShadowType.NONE);

        var custom_field_grid = new Gtk.Grid ();
        custom_field_grid.set_row_spacing (6);
        custom_field_grid.set_column_spacing (12);
        custom_game_screen.add (custom_field_grid);

        label = new Gtk.Label.with_mnemonic (_("H_orizontal:"));
        label.set_alignment (0, 0.5f);
        custom_field_grid.attach (label, 0, 0, 1, 1);

        var field_width_entry = new Gtk.SpinButton.with_range (XSIZE_MIN, XSIZE_MAX, 1);
        field_width_entry.value_changed.connect (xsize_spin_cb);
        field_width_entry.set_value (settings.get_int (KEY_XSIZE));
        custom_field_grid.attach (field_width_entry, 1, 0, 1, 1);
        label.set_mnemonic_widget (field_width_entry);

        label = new Gtk.Label.with_mnemonic (_("_Vertical:"));
        label.set_alignment (0, 0.5f);
        custom_field_grid.attach (label, 0, 1, 1, 1);

        var field_height_entry = new Gtk.SpinButton.with_range (YSIZE_MIN, YSIZE_MAX, 1);
        field_height_entry.value_changed.connect (ysize_spin_cb);
        field_height_entry.set_value (settings.get_int (KEY_YSIZE));
        custom_field_grid.attach (field_height_entry, 1, 1, 1, 1);
        label.set_mnemonic_widget (field_height_entry);

        label = new Gtk.Label.with_mnemonic (_("_Number of mines:"));
        label.set_alignment (0, 0.5f);
        custom_field_grid.attach (label, 0, 2, 1, 1);

        n_mines_spin = new Gtk.SpinButton.with_range (1, XSIZE_MAX * YSIZE_MAX, 1);
        n_mines_spin.value_changed.connect (n_mines_spin_cb);
        n_mines_spin.set_value (settings.get_int (KEY_NMINES));
        custom_field_grid.attach (n_mines_spin, 1, 2, 1, 1);

        set_n_mines_limit ();
        label.set_mnemonic_widget (n_mines_spin);

        var hbox = new Gtk.HBox (false, 5);
        custom_field_grid.attach (hbox, 0, 3, 2, 1);

        var button_back = new Gtk.Button.from_stock (Gtk.Stock.CANCEL);
        button_back.clicked.connect (show_new_game_screen);
        hbox.pack_start (button_back, true, true);

        button_custom = new Gtk.Button.with_mnemonic (_("_Play Game"));
        button_custom.set_image (new Gtk.Image.from_stock (Gtk.Stock.GO_FORWARD, Gtk.IconSize.BUTTON));
        button_custom.clicked.connect (custom_size_clicked_cb);
        hbox.pack_start (button_custom, true, true);

        custom_game_screen.show_all ();
        custom_game_screen.hide ();
        view_box.pack_start (custom_game_screen, true, false);

        tick_cb ();
    }

    private bool window_configure_event_cb (Gdk.EventConfigure event)
    {
        if (!is_maximized && !is_fullscreen)
        {
            window_width = event.width;
            window_height = event.height;
        }

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
        if (minefield_view.minefield.paused)
        {
            minefield_view.minefield.paused = false;
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

    /* Show the high scores dialog - creating it if necessary. If pos is
     * greater than 0 the appropriate score is highlighted. If the score isn't
     * a high score and this isn't a direct request to see the scores, we
     * only show a simple dialog. */
    private int show_scores (int pos, bool endofgame)
    {
        if (endofgame && (pos <= 0))
        {
            var dialog = new Gtk.MessageDialog.with_markup (window,
                                                            Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                                            Gtk.MessageType.INFO,
                                                            Gtk.ButtonsType.NONE,
                                                            "<b>%s</b>\n%s",
                                                            _("The Mines Have Been Cleared!"),
                                                            _("Great work, but unfortunately your score did not make the top ten."));
            dialog.add_buttons (Gtk.Stock.QUIT, Gtk.ResponseType.REJECT,
                                _("_New Game"), Gtk.ResponseType.ACCEPT, null);
            dialog.set_default_response (Gtk.ResponseType.ACCEPT);
            dialog.set_title ("");
            var result = dialog.run ();
            dialog.destroy ();
            return result;
        }
        else
        {
            var dialog = new GnomeGamesSupport.ScoresDialog (window, highscores, _("Mines Scores"));
            dialog.set_category_description (_("Size:"));

            if (pos > 0)
            {
                dialog.set_hilight (pos);
                var message = "<b>%s</b>\n\n%s".printf (_("Congratulations!"), pos == 1 ? _("Your score is the best!") : _("Your score has made the top ten."));
                dialog.set_message (message);
            }
            else
                dialog.set_message (null);

            if (endofgame)
                dialog.set_buttons (GnomeGamesSupport.ScoresButtons.QUIT_BUTTON | GnomeGamesSupport.ScoresButtons.NEW_GAME_BUTTON);
            else
                dialog.set_buttons (0);
            var result = dialog.run ();
            dialog.destroy ();
            return result;
        }
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
        show_scores (0, false);
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
            toggle_pause_cb ();
            var dialog = new Gtk.MessageDialog (window, Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, "%s", _("Do you want to start a new game?"));
            dialog.secondary_text = (_("If you start a new game, your current progress will be lost."));
            dialog.add_buttons (_("Keep Current Game"), Gtk.ResponseType.DELETE_EVENT,
                                _("Start New Game"), Gtk.ResponseType.ACCEPT,
                                null);
            var result = dialog.run ();
            dialog.destroy ();
            if (result != Gtk.ResponseType.ACCEPT)
            {
                toggle_pause_cb ();
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
            SignalHandler.disconnect_by_func (minefield, null, this);
        minefield = null;

        is_new_game_screen = true;
        custom_game_screen.hide ();
        minefield_view.hide ();
        new_game_screen.show ();
        flag_label.set_text("");
        set_face_image (smile_face_image);

        new_game_action.set_enabled (false);
        repeat_size_action.set_enabled (false);
        hint_action.set_enabled (false);
        pause_action.set_enabled (false);

        minefield_view.minefield.paused = false;
    }

    private void start_game ()
    {
        is_new_game_screen = false;
        custom_game_screen.hide ();
        minefield_view.show ();
        new_game_screen.hide ();

        set_face_image (smile_face_image);

        int x, y, n;
        var score_key = "";
        switch (settings.get_int (KEY_MODE))
        {
        case 0:
            x = 8;
            y = 8;
            n = 10;
            score_key = "Small";
            break;
        case 1:
            x = 16;
            y = 16;
            n = 40;
            score_key = "Medium";
            break;
        case 2:
            x = 30;
            y = 16;
            n = 99;
            score_key = "Large";
            break;
        default:
        case 3:
            x = settings.get_int (KEY_XSIZE).clamp (XSIZE_MIN, XSIZE_MAX);
            y = settings.get_int (KEY_YSIZE).clamp (YSIZE_MIN, YSIZE_MAX);
            n = settings.get_int (KEY_NMINES).clamp (1, x * y - 10);
            score_key = "Custom";
            break;
        }

        highscores.set_category (score_key);
        if (minefield != null)
            SignalHandler.disconnect_by_func (minefield, null, this);
        minefield = new Minefield (x, y, n);
        minefield.marks_changed.connect (marks_changed_cb);
        minefield.explode.connect (explode_cb);
        minefield.cleared.connect (cleared_cb);
        minefield.tick.connect (tick_cb);

        minefield_view.minefield = minefield;

        update_flag_label ();

        new_game_action.set_enabled (true);
        repeat_size_action.set_enabled (true);
        hint_action.set_enabled (true);
        pause_action.set_enabled (true);

        minefield_view.minefield.paused = false;
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
        if (!minefield_view.minefield.paused)
        {
            minefield_view.minefield.paused = true;
            hint_action.set_enabled (false);
            pause_button.icon_name = "media-playback-start";
            pause_button.label = _("Res_ume");
        }
        else
        {
            minefield_view.minefield.paused = false;
            hint_action.set_enabled (true);
            pause_button.icon_name = "media-playback-pause";
            pause_button.label = _("_Pause");
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

        var seconds = (int) (minefield.elapsed + 0.5);
        var pos = highscores.add_time_score ((float) (seconds / 60) + (float) (seconds % 60) / 100);

        if (show_scores (pos, true) == Gtk.ResponseType.REJECT)
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

        Gtk.show_about_dialog (window,
                               "name", _("Mines"),
                               "version", VERSION,
                               "comments",
                               _("The popular logic puzzle minesweeper. Clear mines from a board using hints from squares you have already uncovered.\n\nMines is a part of GNOME Games."),
                               "copyright",
                               "Copyright \xc2\xa9 1997-2008 Free Software Foundation, Inc.",
                               "license", GnomeGamesSupport.get_license (_("Mines")),
                               "authors", authors,
                               "artists", artists,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "gnomine", "website",
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
            Gtk.show_uri (window.get_screen (), "help:gnomine", Gtk.get_current_event_time ());
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

        GnomeGamesSupport.scores_startup ();

        var context = new OptionContext ("");
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

        var app = new GnoMine ();
        return app.run ();
    }
}
