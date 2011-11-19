public class GnoMine
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
    private Gtk.Image win_face_image;
    private Gtk.Image sad_face_image;
    private Gtk.Image smile_face_image;
    private Gtk.Image cool_face_image;
    private Gtk.Image worried_face_image;
    private Gtk.Image? current_face_image = null;

    /* Main window */
    private Gtk.Window window;

    /* Minefield widget */
    private Minefield minefield;
    private MinefieldView minefield_view;

    private Gtk.Dialog? pref_dialog = null;
    private Gtk.Label flag_label;
    private Gtk.SpinButton n_mines_spin;
    private Gtk.Button new_game_button;
    private GnomeGamesSupport.Frame custom_size_frame;
    private GnomeGamesSupport.Clock clock;
    private Gtk.Action hint_action;
    private GnomeGamesSupport.FullscreenAction fullscreen_action;
    private GnomeGamesSupport.PauseAction pause_action;

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
        settings = new Settings ("org.gnome.gnomine");

        highscores = new GnomeGamesSupport.Scores ("gnomine", scorecats, "board size", null, 0 /* default category */, GnomeGamesSupport.ScoreStyle.TIME_ASCENDING);

        Gtk.Window.set_default_icon_name ("gnome-mines");

        window = new Gtk.Window (Gtk.WindowType.TOPLEVEL);
        window.border_width = 6;
        window.title = _("Mines");

        GnomeGamesSupport.settings_bind_window_state ("/org/gnome/gnomine/", window);

        GnomeGamesSupport.stock_init ();

        window.delete_event.connect (delete_event_cb);

        var main_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        window.add (main_vbox);
        main_vbox.show ();

        var ui_manager = create_ui_manager ("GnomineActions");
        window.add_accel_group (ui_manager.get_accel_group ());
        var menubar = (Gtk.MenuBar) ui_manager.get_widget ("/MainMenu");
        menubar.show ();
        main_vbox.pack_start (menubar, false, false, 0);

        var new_game_button_alignment = new Gtk.Alignment (0.5f, 0.5f, 0.0f, 0.0f);
        main_vbox.pack_start (new_game_button_alignment, false, false, 0);
        new_game_button_alignment.show ();

        new_game_button = new Gtk.Button ();
        new_game_button.clicked.connect (new_game);
        new_game_button_alignment.add (new_game_button);
        new_game_button.show ();

        var face_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        new_game_button.add (face_box);
        face_box.show ();

        win_face_image = load_face_image ("face-win.svg");
        sad_face_image = load_face_image ("face-sad.svg");
        smile_face_image = load_face_image ("face-smile.svg");
        cool_face_image = load_face_image ("face-cool.svg");
        worried_face_image = load_face_image ("face-worried.svg");

        face_box.pack_start (win_face_image, false, false, 0);
        face_box.pack_start (sad_face_image, false, false, 0);
        face_box.pack_start (smile_face_image, false, false, 0);
        face_box.pack_start (cool_face_image, false, false, 0);
        face_box.pack_start (worried_face_image, false, false, 0);

        var separator = new Gtk.HSeparator ();
        main_vbox.pack_start (separator, false, false, 0);
        separator.show ();

        minefield_view = new MinefieldView ();
        minefield_view.set_use_question_marks (settings.get_boolean (KEY_USE_QUESTION_MARKS));
        minefield_view.set_use_overmine_warning (settings.get_boolean (KEY_USE_OVERMINE_WARNING));
        minefield_view.set_use_autoflag (settings.get_boolean (KEY_USE_AUTOFLAG));
        minefield_view.button_press_event.connect (view_button_press_event);
        minefield_view.look.connect (look_cb);
        minefield_view.unlook.connect (unlook_cb);
        main_vbox.pack_start (minefield_view, true, true, 0);
        minefield_view.show ();

        separator = new Gtk.HSeparator ();
        main_vbox.pack_start (separator, false, false, 0);
        separator.show ();

        var status_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        status_box.homogeneous = true;
        main_vbox.pack_start (status_box, false, false, 0);
        status_box.show ();

        flag_label = new Gtk.Label ("");
        status_box.pack_start (flag_label, false, false, 0);
        flag_label.show ();

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        status_box.pack_start (box, false, false, 0);
        box.show ();

        var label = new Gtk.Label (_("Time: "));
        box.pack_start (label, false, false, 0);

        clock = new GnomeGamesSupport.Clock ();
        box.pack_start (clock, false, false, 0);
        clock.show ();

        new_game ();
    }

    public void start ()
    {
        window.show ();

        /* All this hiding is a bit ugly, but it's better than a ton of show calls. */
        win_face_image.hide ();
        sad_face_image.hide ();
        cool_face_image.hide ();
        worried_face_image.hide ();

        set_face_image (smile_face_image);
    }

    private Gtk.Image load_face_image (string name)
    {
        var image = new Gtk.Image ();
        var dname = GnomeGamesSupport.runtime_get_directory (GnomeGamesSupport.RuntimeDirectory.GAME_PIXMAP_DIRECTORY);
        var filename = Path.build_filename (dname, name);

        if (filename != null)
            image.set_from_file (filename);

        return image;
    }

    private void set_face_image (Gtk.Image face_image)
    {
        if (current_face_image == face_image)
            return;

        if (current_face_image != null)
            current_face_image.hide ();
        hint_action.set_sensitive ((face_image == cool_face_image) || (face_image == smile_face_image));
        face_image.show ();

        current_face_image = face_image;
    }

    private bool delete_event_cb (Gdk.EventAny event)
    {
        Gtk.main_quit ();
        return false;    
    }

    private bool view_button_press_event (Gtk.Widget widget, Gdk.EventButton event)
    {
        /* Cancel pause on click */
        if (pause_action.get_is_paused ())
        {
            pause_action.set_is_paused (false);
            return true;
        }

        return false;
    }

    private void quit_game_cb ()
    {
        Gtk.main_quit ();
    }

    private void update_flag_label ()
    {
        flag_label.set_text ("Flags: %u/%u".printf (minefield.n_flags, minefield.n_mines));
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

    private void scores_cb ()
    {
        show_scores (0, false);
    }

    private void new_game ()
    {
        if (minefield != null && minefield.n_cleared > 0 && !minefield.exploded && !minefield.is_complete)
        {
            var dialog = new Gtk.MessageDialog (window, Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, "%s", _("Cancel current game?"));
            dialog.add_buttons (_("Start New Game"), Gtk.ResponseType.ACCEPT,
                                _("Keep Current Game"), Gtk.ResponseType.REJECT,
                                null);
            var result = dialog.run ();
            dialog.destroy ();
            if (result == Gtk.ResponseType.REJECT)
                return;
        }

        clock.reset ();
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

        minefield_view.minefield = minefield;

        update_flag_label ();

        pause_action.set_sensitive (true);
        minefield_view.paused = false;
    }

    private void hint_cb ()
    {
        uint x, y;
        minefield.hint (out x, out y);

        /* There is a ten second penalty for accepting a hint. */
        minefield.clear_mine (x, y);
        clock.add_seconds (10);
    }

    private void new_game_cb ()
    {
        new_game ();
    }

    private void pause_cb (Gtk.Action action)
    {
        if (pause_action.get_is_paused ())
        {
            minefield_view.paused = true;
            hint_action.set_sensitive (false);
            clock.stop ();
        }
        else
        {
            minefield_view.paused = false;
            hint_action.set_sensitive (true);
            clock.start ();
        }
    }

    private void marks_changed_cb (Minefield minefield)
    {
        update_flag_label ();
        clock.start ();
    }

    private void explode_cb (Minefield minefield)
    {
        set_face_image (sad_face_image);

        new_game_button.grab_focus ();

        clock.stop ();
    }

    private void cleared_cb (Minefield minefield)
    {
        clock.stop ();

        new_game_button.grab_focus ();

        set_face_image (win_face_image);

        var seconds = clock.get_seconds ();
        var pos = highscores.add_time_score ((float) (seconds / 60) + (float) (seconds % 60) / 100);

        if (show_scores (pos, true) == Gtk.ResponseType.REJECT)
            Gtk.main_quit ();
        else
            new_game ();
    }

    private void look_cb (MinefieldView minefield_view)
    {
        set_face_image (worried_face_image);
        clock.start ();
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
            "Horacio J. Pe\xc3\xb1a",
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
        new_game ();
    }

    private void ysize_spin_cb (Gtk.SpinButton spin)
    {
        var ysize = spin.get_value_as_int ();        
        if (ysize == settings.get_int (KEY_YSIZE))
            return;

        settings.set_int (KEY_YSIZE, ysize);
        set_n_mines_limit ();
        new_game ();
    }

    private void n_mines_spin_cb (Gtk.SpinButton spin)
    {
        var n_mines = spin.get_value_as_int ();
        if (n_mines == settings.get_int (KEY_NMINES))
            return;

        settings.set_int (KEY_NMINES, n_mines);
        new_game ();
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
        var table = new Gtk.Table (3, 2, false);
        table.border_width = 5;
        table.set_row_spacings (18);
        table.set_col_spacings (18);

        var frame = new GnomeGamesSupport.Frame (_("Field Size"));

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);

        var small_button = new Gtk.RadioButton.with_mnemonic (null, dpgettext2 (null, "board size", "_Small"));
        small_button.toggled.connect (small_size_toggled_cb);
        vbox.pack_start (small_button, false, false, 0);

        var medium_button = new Gtk.RadioButton.with_mnemonic (small_button.get_group (), dpgettext2 (null, "board size", "_Medium"));
        medium_button.toggled.connect (medium_size_toggled_cb);
        vbox.pack_start (medium_button, false, false, 0);

        var large_button = new Gtk.RadioButton.with_mnemonic (medium_button.get_group (), dpgettext2 (null, "board size", "_Large"));
        large_button.toggled.connect (large_size_toggled_cb);
        vbox.pack_start (large_button, false, false, 0);

        var custom_button = new Gtk.RadioButton.with_mnemonic (large_button.get_group (), dpgettext2 (null, "board size", "_Custom"));
        custom_button.toggled.connect (custom_size_toggled_cb);
        vbox.pack_start (custom_button, false, false, 0);

        switch (settings.get_int (KEY_MODE))
        {
        case 0:
            small_button.active = true;
            break;
        case 1:
            medium_button.active = true;
            break;
        case 2:
            large_button.active = true;
            break;
        default:
        case 3:
            custom_button.active = true;
            break;
        }

        frame.add (vbox);

        table.attach_defaults (frame, 0, 1, 0, 1);

        custom_size_frame = new GnomeGamesSupport.Frame (_("Custom Size"));
        custom_size_frame.sensitive = settings.get_int (KEY_MODE) == 3;

        var custom_field_table = new Gtk.Table (2, 2, false);
        custom_field_table.set_row_spacings (6);
        custom_field_table.set_col_spacings (12);
        custom_size_frame.add (custom_field_table);

        var label = new Gtk.Label.with_mnemonic (_("_Number of mines:"));
        label.set_alignment (0, 0.5f);
        custom_field_table.attach (label, 0, 1, 2, 3, Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL, 0, 0, 0);

        n_mines_spin = new Gtk.SpinButton.with_range (1, XSIZE_MAX * YSIZE_MAX, 1);
        n_mines_spin.value_changed.connect (n_mines_spin_cb);
        n_mines_spin.set_value (settings.get_int (KEY_NMINES));
        custom_field_table.attach (n_mines_spin, 1, 2, 2, 3, 0, 0, 0, 0);
        set_n_mines_limit ();
        label.set_mnemonic_widget (n_mines_spin);

        label = new Gtk.Label.with_mnemonic (_("_Horizontal:"));
        label.set_alignment (0, 0.5f);
        custom_field_table.attach (label, 0, 1, 0, 1, Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL, 0, 0, 0);

        var field_width_entry = new Gtk.SpinButton.with_range (XSIZE_MIN, XSIZE_MAX, 1);
        field_width_entry.value_changed.connect (xsize_spin_cb);
        field_width_entry.set_value (settings.get_int (KEY_XSIZE));
        custom_field_table.attach (field_width_entry, 1, 2, 0, 1, 0, 0, 0, 0);
        label.set_mnemonic_widget (field_width_entry);

        label = new Gtk.Label.with_mnemonic (_("_Vertical:"));
        label.set_alignment (0, 0.5f);
        custom_field_table.attach (label, 0, 1, 1, 2, Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL, 0, 0, 0);

        var field_height_entry = new Gtk.SpinButton.with_range (YSIZE_MIN, YSIZE_MAX, 1);
        field_height_entry.value_changed.connect (ysize_spin_cb);
        field_height_entry.set_value (settings.get_int (KEY_YSIZE));
        custom_field_table.attach (field_height_entry, 1, 2, 1, 2, 0, 0, 0, 0);
        label.set_mnemonic_widget (field_height_entry);

        table.attach (custom_size_frame, 1, 2, 0, 1, Gtk.AttachOptions.FILL, Gtk.AttachOptions.FILL, 0, 0);

        frame = new GnomeGamesSupport.Frame (_("Flags"));
        table.attach_defaults (frame, 0, 2, 1, 2);
        
        var flag_options_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        flag_options_vbox.show ();
        frame.add (flag_options_vbox);

        var question_toggle = new Gtk.CheckButton.with_mnemonic (_("_Use \"I'm not sure\" flags"));
        question_toggle.toggled.connect (use_question_toggle_cb);
        question_toggle.set_active (settings.get_boolean (KEY_USE_QUESTION_MARKS));
        flag_options_vbox.pack_start (question_toggle, false, true, 0);

        var overmine_toggle = new Gtk.CheckButton.with_mnemonic (_("_Warn if too many flags placed"));
        overmine_toggle.toggled.connect (use_overmine_toggle_cb);
        overmine_toggle.set_active (settings.get_boolean (KEY_USE_OVERMINE_WARNING));
        flag_options_vbox.pack_start (overmine_toggle, false, true, 0);

        var dialog = new Gtk.Dialog.with_buttons (_("Mines Preferences"),
                                                  window,
                                                  0,
                                                  Gtk.Stock.CLOSE,
                                                  Gtk.ResponseType.CLOSE, null);
        dialog.set_border_width (5);
        dialog.set_resizable (false);
        var box = (Gtk.Box) dialog.get_content_area ();
        box.set_spacing (2);
        box.pack_start (table, false, false, 0);

        dialog.response.connect (pref_response_cb);
        dialog.delete_event.connect (pref_delete_event_cb);

        table.show_all ();

        return dialog;
    }
    
    private void set_mode (int mode)
    {
        if (mode == settings.get_int (KEY_MODE))
            return;

        settings.set_int (KEY_MODE, mode);
        custom_size_frame.sensitive = mode == 3;
        new_game ();
    }

    private void small_size_toggled_cb (Gtk.ToggleButton button)
    {
        if (button.active)
            set_mode (0);
    }

    private void medium_size_toggled_cb (Gtk.ToggleButton button)
    {
        if (button.active)
            set_mode (1);
    }

    private void large_size_toggled_cb (Gtk.ToggleButton button)
    {
        if (button.active)
            set_mode (2);
    }

    private void custom_size_toggled_cb (Gtk.ToggleButton button)
    {
        if (button.active)
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
        GnomeGamesSupport.help_display (window, "gnomine", null);
    }

    private const Gtk.ActionEntry actions[] =
    {
        {"GameMenu", null, N_("_Game")},
        {"SettingsMenu", null, N_("_Settings")},
        {"HelpMenu", null, N_("_Help")},
        {"NewGame", GnomeGamesSupport.STOCK_NEW_GAME, null, null, null, new_game_cb},
        {"Hint", GnomeGamesSupport.STOCK_HINT, null, null, null, hint_cb},
        {"Scores", GnomeGamesSupport.STOCK_SCORES, null, null, null, scores_cb},
        {"Quit", Gtk.Stock.QUIT, null, null, null, quit_game_cb},
        {"Preferences", Gtk.Stock.PREFERENCES, null, null, null, preferences_cb},
        {"Contents", GnomeGamesSupport.STOCK_CONTENTS, null, null, null, help_cb},
        {"About", Gtk.Stock.ABOUT, null, null, null, about_cb}
    };

    private const string ui_description =
        "<ui>" +
        "    <menubar name='MainMenu'>" +
        "        <menu action='GameMenu'>" +
        "            <menuitem action='NewGame'/>" +
        "            <menuitem action='Hint'/>" +
        "            <menuitem action='PauseGame'/>" +
        "            <separator/>" +
        "            <menuitem action='Scores'/>" +
        "            <separator/>" +
        "            <menuitem action='Quit'/>" +
        "        </menu>" +
        "        <menu action='SettingsMenu'>" +
        "            <menuitem action='Fullscreen'/>" +
        "            <menuitem action='Preferences'/>" +
        "        </menu>" +
        "        <menu action='HelpMenu'>" +
        "            <menuitem action='Contents'/>" +
        "            <menuitem action='About'/>" +
        "        </menu>" +
        "    </menubar>" +
        "</ui>";

    private Gtk.UIManager create_ui_manager (string group)
    {
        var action_group = new Gtk.ActionGroup ("group");
        action_group.set_translation_domain (GETTEXT_PACKAGE);
        action_group.add_actions (actions, this);

        var ui_manager = new Gtk.UIManager ();
        ui_manager.insert_action_group (action_group, 0);
        try
        {
            ui_manager.add_ui_from_string (ui_description, -1);
        }
        catch (Error e)
        {
        }
        hint_action = action_group.get_action ("Hint");

        fullscreen_action = new GnomeGamesSupport.FullscreenAction ("Fullscreen", window);
        action_group.add_action_with_accel (fullscreen_action, null);

        pause_action = new GnomeGamesSupport.PauseAction ("PauseGame");
        pause_action.state_changed.connect (pause_cb);
        action_group.add_action_with_accel (pause_action, null);

        return ui_manager;
    }

    public static int main (string[] args)
    {
        if (!GnomeGamesSupport.runtime_init ("gnomine"))
            return 1;

#if ENABLE_SETGID
        GnomeGamesSupport.setgid_io_init ();
#endif

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

        Environment.set_application_name (_("Mines"));

        var app = new GnoMine ();
        app.start ();

        Gtk.main ();

        Settings.sync ();

        GnomeGamesSupport.runtime_shutdown ();

        return Posix.EXIT_SUCCESS;
    }
}
