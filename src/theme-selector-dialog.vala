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

    public ThemeSelectorDialog ( )
    {
        set_default_size (300, 332);
        title = _("Select theme");
        var frame = new Gtk.AspectFrame (null, 0.5f, 0.5f, 1.0f, false);
        frame.border_width = 6;
        get_content_area ().pack_start (frame, true, true, 0);

        var settings = new Settings ("org.gnome.mines");
        settings.delay ();

        var view = new MinefieldView (settings);
        view.minefield = new PreviewField ();
        frame.add (view);
        frame.show_all ();

        reveal_nonmines (view);
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
