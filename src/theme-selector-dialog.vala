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
                stdout.printf ("%s\n", info.get_name ());
                themes.append (info.get_name ());
            }
        }
        return themes;
    }

    public ThemeSelectorDialog ( )
    {
        title = _("Select theme");

        var overlay = new Gtk.Overlay ();
        var frame = new Gtk.AspectFrame (null, 0.5f, 0.5f, 1.0f, false);
        frame.border_width = 6;
        get_content_area ().pack_start (overlay, true, true, 0);

        var previous = new Gtk.Button.from_icon_name ("go-previous", Gtk.IconSize.LARGE_TOOLBAR);
        previous.show ();
        previous.valign = Gtk.Align.CENTER;
        previous.halign = Gtk.Align.START;
        previous.get_style_context ().add_class ("navigation");
        overlay.add_overlay (previous);

        var next = new Gtk.Button.from_icon_name ("go-next", Gtk.IconSize.LARGE_TOOLBAR);
        next.show ();
        next.valign = Gtk.Align.CENTER;
        next.halign = Gtk.Align.END;
        next.get_style_context ().add_class ("navigation");
        overlay.add_overlay (next);

        var settings = new Settings ("org.gnome.mines");
        settings.delay ();

        var view = new MinefieldView (settings);
        view.minefield = new PreviewField ();
        frame.add (view);
        overlay.add (frame);
        overlay.show_all ();

        reveal_nonmines (view);
        set_size_request (320, 300);
        resizable = false;
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
