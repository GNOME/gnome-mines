private class PreviewField : Minefield
{
    public PreviewField ()
    {
        base (7, 7, 20);

        place_mines (0, 0);
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
    private Settings settings;
    public List<string> list_themes ()
    {
        string themes_dir = Path.build_path (Path.DIR_SEPARATOR_S, DATA_DIRECTORY, "themes");
        List<string> themes = new List<string> ();
        File file = File.new_for_path (themes_dir);
        FileEnumerator enumerator = file.enumerate_children ("standard::*",
                                                              FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                                              null);

        FileInfo info = null;
        while ((info = enumerator.next_file (null)) != null) {
            if (info.get_file_type () == FileType.DIRECTORY) {
                themes.append (info.get_name ());
            }
        }
        return themes;
    }

    private Gtk.Widget create_preview_widget (out MinefieldView view) {
        view = new MinefieldView (settings);
        view.minefield = new PreviewField ();

        var frame = new Gtk.AspectFrame (null, 0.5f, 0.5f, 1.0f, false);
        frame.border_width = 6;
        frame.add (view);
        reveal_nonmines (view);
        return frame;
    }

    public ThemeSelectorDialog ( )
    {
        MinefieldView minefield;

        title = _("Select theme");

        var overlay = new Gtk.Overlay ();
        get_content_area ().pack_start (overlay, true, true, 0);

        previous = new Gtk.Button.from_icon_name ("go-previous", Gtk.IconSize.LARGE_TOOLBAR);
        previous.show ();
        previous.valign = Gtk.Align.CENTER;
        previous.halign = Gtk.Align.START;
        previous.get_style_context ().add_class ("navigation");
        overlay.add_overlay (previous);

        next = new Gtk.Button.from_icon_name ("go-next", Gtk.IconSize.LARGE_TOOLBAR);
        next.show ();
        next.valign = Gtk.Align.CENTER;
        next.halign = Gtk.Align.END;
        next.get_style_context ().add_class ("navigation");
        overlay.add_overlay (next);

        settings = new Settings ("org.gnome.mines");
        settings.delay ();

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

        overlay.add (create_preview_widget (out minefield));

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

        update_sensitivities (themes, current_index);
        overlay.show_all ();

        set_size_request (320, 300);
//        resizable = false;
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
