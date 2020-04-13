private class PreviewField : Minefield
{
    private const Neighbour neighbour_map[] =
    {
        { -1,  1 },
        {  0,  1 },
        {  1,  1 },
        {  1,  0 },
        {  1, -1 },
        {  0, -1 },
        { -1, -1 },
        { -1,  0 }
    };

    private const int SIZE = 7;
    public PreviewField ()
    {
        base (SIZE, SIZE, 3*SIZE);

        place_mines (0, 0);
        placed_mines = true;
    }

    protected new void place_mines (uint x, uint y)
    {
        for (int i = 0; i < SIZE; i++)
            locations[i, 0].has_mine = i >= 5;
        for (int i = 0; i < SIZE; i++)
            locations[i, 1].has_mine = false;
        for (int i = 0; i < SIZE; i++)
            locations[i, 2].has_mine = i == 0 || i == 3;
        for (int i = 0; i < SIZE; i++)
            locations[i, 3].has_mine = i == 0 || i == 2;
        for (int i = 0; i < SIZE; i++)
            locations[i, 4].has_mine = i == 0 || i == 2 || i > 3;
        for (int i = 0; i < SIZE; i++)
            locations[i, 5].has_mine = i % 2 == 0;
        for (int i = 0; i < SIZE; i++)
            locations[i, 6].has_mine = i != 1;
        for (int i = 0; i < SIZE; i++)
            for (int j = 0; j < SIZE; j++)
                foreach (var neighbour in neighbour_map)
                    {
                        var nx = i + neighbour.x;
                        var ny = j + neighbour.y;
                        if (is_location(nx, ny) && locations[nx, ny].has_mine)
                            locations[i, j].adjacent_mines++;
                    }
    }
}

public class ThemeSelectorDialog : Gtk.Dialog
{

    private Gtk.Button previous;
    private Gtk.Button next;
    private Settings settings = new Settings ("org.gnome.Mines");
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

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        var frame = new Gtk.AspectFrame (null, 0.5f, 0.5f, 1.0f, false);
        frame.margin_start = 6;
        frame.margin_end = 6;
        frame.margin_top = 6;
        frame.margin_bottom = 6;
        frame.add (view);
        reveal_nonmines (view);
        box.add (frame);

        return box;
    }

    public ThemeSelectorDialog (Gtk.Window parent)
    {
        MinefieldView minefield;

        Object (use_header_bar: 1, title:  _("Select Theme"),
                modal: true, transient_for: parent, resizable: false, margin_start: 12, margin_end: 12, margin_top: 12, margin_bottom: 12);

        previous = new Gtk.Button.from_icon_name ("go-previous-symbolic");
        previous.valign = Gtk.Align.CENTER;
        previous.halign = Gtk.Align.START;

        next = new Gtk.Button.from_icon_name ("go-next-symbolic");
        next.valign = Gtk.Align.CENTER;
        next.halign = Gtk.Align.END;

        var buttons_holder = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        var headerbar = get_header_bar () as Gtk.HeaderBar;
        headerbar.set_show_title_buttons (true);
        get_content_area ().add (create_preview_widget (out minefield));

        buttons_holder.add (previous);
        buttons_holder.add (next);
        buttons_holder.get_style_context ().add_class ("linked");
        headerbar.pack_start (buttons_holder);

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
        });

        previous.clicked.connect (() => {
            switch_theme_preview (--current_index, themes);
            update_sensitivities (themes, current_index);
        });

        set_size_request (420, 400);
        update_sensitivities (themes, current_index);
    }

    private void switch_theme_preview (int to_index, List<string> themes)
    {
        settings.set_string ("theme", themes.nth_data (to_index));
        this.queue_draw ();
        this.get_window ().invalidate_rect (null, true);
        this.present ();
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
                    view.minefield.multi_release (i, j);
                } else {
                    view.toggle_mark (i, j);
                }
            }
    }
}
