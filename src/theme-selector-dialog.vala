private class PreviewField : Minefield
{
    public PreviewField ()
    {
        base (7, 7, 20);

        place_mines (0, 0);
        placed_mines = true;
    }

    protected new void place_mines (uint x, uint y)
    {
        for (int i = 0; i < 7; i++)
            locations[i, 0].has_mine = i >= 5;
        for (int i = 0; i < 7; i++)
            locations[i, 1].has_mine = false;
        for (int i = 0; i < 7; i++)
            locations[i, 2].has_mine = i == 0 || i == 3;
        for (int i = 0; i < 7; i++)
            locations[i, 3].has_mine = i == 0 || i == 2;
        for (int i = 0; i < 7; i++)
            locations[i, 4].has_mine = i == 0 || i == 2 || i > 3;
        for (int i = 0; i < 7; i++)
            locations[i, 5].has_mine = i % 2 == 0;
        for (int i = 0; i < 7; i++)
            locations[i, 6].has_mine = i != 1;

    }

}

public class ThemeSelectorDialog : Gtk.Dialog
{

    private Gtk.Button previous;
    private Gtk.Button next;
    private Settings settings = new Settings ("org.gnome.mines");
    public List<string> list_themes ()
    {
        string themes_dir = Path.build_path (Path.DIR_SEPARATOR_S, DATA_DIRECTORY, "themes");
        List<string> themes = new List<string> ();
        File file = File.new_for_path (themes_dir);

        try
        {
            FileEnumerator enumerator = file.enumerate_children ("standard::*",
                                                                  FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                                                  null);

            FileInfo info = null;

            while ((info = enumerator.next_file (null)) != null) {
                if (info.get_file_type () == FileType.DIRECTORY) {
                    themes.append (info.get_name ());
                }
            }
        }
        catch (Error e)
        {
            error ("Error enumerating themes from directory %s : %s\n", themes_dir, e.message);
        }
        return themes;
    }

    private Gtk.Widget create_preview_widget (out MinefieldView view)
    {
        view = new MinefieldView (settings);
        view.minefield = new PreviewField ();

        var frame = new Gtk.AspectFrame (null, 0.5f, 0.5f, 1.0f, false);
        frame.border_width = 6;
        frame.add (view);
        reveal_nonmines (view);
        return frame;
    }

    public ThemeSelectorDialog ( Gtk.Window parent )
    {
        var desktop = Environment.get_variable ("XDG_CURRENT_DESKTOP");
        bool use_headerbar = desktop == null || desktop != "Unity";
        MinefieldView minefield;

        Object (use_header_bar: use_headerbar ? 1 : 0, title:  _("Select Theme"),
                modal: true, transient_for: parent, resizable: false);

        previous = new Gtk.Button.from_icon_name ("go-previous-symbolic", Gtk.IconSize.BUTTON);
        previous.valign = Gtk.Align.CENTER;
        previous.halign = Gtk.Align.START;

        next = new Gtk.Button.from_icon_name ("go-next-symbolic", Gtk.IconSize.BUTTON);
        next.valign = Gtk.Align.CENTER;
        next.halign = Gtk.Align.END;

        if (use_headerbar) {
            var headerbar = get_header_bar () as Gtk.HeaderBar;
            headerbar.set_show_close_button (true);
            get_content_area ().pack_start (create_preview_widget (out minefield), true, true, 0);
            headerbar.pack_start (previous);
            headerbar.pack_start (next);
        } else {
            add_button (_("Close"), Gtk.ResponseType.DELETE_EVENT);
            border_width = 12;
            var buttons_holder = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            buttons_holder.pack_start (previous, false, false, 0);
            buttons_holder.pack_start (create_preview_widget (out minefield), true, true, 0);
            buttons_holder.pack_start (next, false, false, 0);
            get_content_area ().pack_end (buttons_holder, true, true, 0);
        }

        var themes = list_themes ();
        var current_theme = settings.get_string ("theme");
        var current_index = 0;
        for (int i = 0; i < themes.length (); i++)
        {
            var theme = themes.nth_data (i);

            if (current_theme == theme) {
                current_index = i;
            }
        }

        next.clicked.connect (() => {
            switch_theme_preview (++current_index, themes);
            update_sensitivities (themes, current_index);
            minefield.refresh ();
        });

        previous.clicked.connect (() => {
            switch_theme_preview (--current_index, themes);
            update_sensitivities (themes, current_index);
            minefield.refresh ();
        });

        set_size_request (420, 400);
        update_sensitivities (themes, current_index);
        show_all ();
    }

    private void switch_theme_preview (int to_index, List<string> themes)
    {
        settings.set_string ("theme", themes.nth_data (to_index));
        settings.apply ();
        this.queue_draw ();
        this.get_window ().invalidate_rect (null, true);
        this.present ();
        //this.show_all ();
    }

    private void update_sensitivities (List themes, int current_index)
    {
        next.set_sensitive (current_index < themes.length ()-1);
        previous.set_sensitive (current_index > 0);
    }

    private void reveal_nonmines (MinefieldView view)
    {
        for (int i = 0; i < 7; i ++)
            for (int j = 0; j < 6; j ++)
            {
                if (!view.minefield.has_mine (i, j)) {
                    view.minefield.clear_mine (i, j);
                    view.multi_release (i, j);
                } else {
                    view.toggle_mark (i, j);
                }
            }
    }

}
