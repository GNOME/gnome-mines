public class ScoreDialog : Gtk.Dialog
{
    private History history;
    private HistoryEntry? selected_entry = null;
    private Gtk.ListStore size_model;
    private Gtk.ListStore score_model;
    private Gtk.ComboBox size_combo;
    private Gtk.TreeView scores;

    public ScoreDialog (History history, HistoryEntry? selected_entry = null, bool show_close = false)
    {
        this.history = history;
        history.entry_added.connect (entry_added_cb);
        this.selected_entry = selected_entry;

        if (show_close)
        {
            add_button (_("_Close"), Gtk.ResponseType.CLOSE);

            var button = add_button (_("New Game"), Gtk.ResponseType.OK);
            button.has_focus = true;
        }
        else
            add_button (_("_OK"), Gtk.ResponseType.DELETE_EVENT);
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

        scores = new Gtk.TreeView ();
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

            if (entry == selected_entry)
            {
                var piter = iter;
                if (score_model.iter_previous (ref piter))
                {
                    var ppiter = piter;
                    if (score_model.iter_previous (ref ppiter))
                        piter = ppiter;
                }
                else
                    piter = iter;
                scores.scroll_to_cell (score_model.get_path (piter), null, false, 0, 0);
            }
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
