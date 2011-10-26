public class MinefieldView : Gtk.Widget
{
    /* true if allowed to mark locations with question marks */
    private bool use_question_marks;

    /* true if should warn when too many flags set */
    private bool use_overmine_warning;

    /* true if automatically set flags on middle click */
    private bool use_autoflag;

    /* Location being clicked on */
    private int selected_x = -1;
    private int selected_y = -1;

    /* Images for flags and mines */
    private GnomeGamesSupport.Preimage flag_preimage;
    private GnomeGamesSupport.Preimage mine_preimage;
    private GnomeGamesSupport.Preimage question_preimage;
    private GnomeGamesSupport.Preimage bang_preimage;
    private GnomeGamesSupport.Preimage warning_preimage;

    /* Pre-rendered images */
    private uint render_size = 0;
    private Cairo.Pattern? flag_pattern;
    private Cairo.Pattern? mine_pattern;
    private Cairo.Pattern? question_pattern;
    private Cairo.Pattern? bang_pattern;
    private Cairo.Pattern? warning_pattern;
    private Cairo.Pattern[] number_patterns;

    private uint mine_size
    {
        get
        {
            return int.min (get_allocated_width () / (int) minefield.width, get_allocated_height () / (int) minefield.height);
        }
    }

    private uint minimum_size
    {
        get
        {
            var w = 320 / minefield.width;
            var h = 200 / minefield.height;
            var s = uint.min (w, h);
            if (s < 20)
                s = 20;
            return s;
        }
    }

    public signal void look ();
    public signal void unlook ();

    public MinefieldView ()
    {
        var pixmap_dir = GnomeGamesSupport.runtime_get_directory (GnomeGamesSupport.RuntimeDirectory.GAME_PIXMAP_DIRECTORY);
        flag_preimage = load_preimage (Path.build_filename (pixmap_dir, "flag.svg"));
        mine_preimage = load_preimage (Path.build_filename (pixmap_dir, "mine.svg"));
        question_preimage = load_preimage (Path.build_filename (pixmap_dir, "flag-question.svg"));
        bang_preimage = load_preimage (Path.build_filename (pixmap_dir, "bang.svg"));
        warning_preimage = load_preimage (Path.build_filename (pixmap_dir, "warning.svg"));
        number_patterns = new Cairo.Pattern[8];
    }
    
    private Minefield _minefield;
    public Minefield minefield
    {
        get { return _minefield; }
        set
        {
            if (_minefield != null)
                SignalHandler.disconnect_by_func (_minefield, null, this);
            _minefield = value;
            selected_x = -1;
            selected_y = -1;
            _minefield.redraw_sector.connect (redraw_sector_cb);
            _minefield.explode.connect (explode_cb);
            queue_resize ();
        }
    }

    public void set_use_question_marks (bool use_question_marks)
    {
        this.use_question_marks = use_question_marks;
    }

    public void set_use_overmine_warning (bool use_overmine_warning)
    {
        this.use_overmine_warning = use_overmine_warning;
        queue_draw ();
    }

    public void set_use_autoflag (bool use_autoflag)
    {
        this.use_autoflag = use_autoflag;
    }

    private void explode_cb (Minefield minefield)
    {
        /* Show the mines that we missed or the flags that were wrong */
        for (var x = 0; x < minefield.width; x++)
            for (var y = 0; y < minefield.height; y++)
                if (minefield.has_mine (x, y) || (!minefield.has_mine (x, y) && minefield.get_flag (x, y) == FlagType.FLAG))
                    redraw_sector_cb (x, y);
    }

    private GnomeGamesSupport.Preimage? load_preimage (string filename)
    {
        try
        {
            return new GnomeGamesSupport.Preimage.from_file (filename);
        }
        catch (Error e)
        {
            return null;
        }
    }

    private Cairo.Pattern render_preimage_pattern (GnomeGamesSupport.Preimage preimage)
    {
        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, (int) mine_size, (int) mine_size);
        var c = new Cairo.Context (surface);
        var pixbuf = preimage.render ((int) mine_size - 2, (int) mine_size - 2);
        Gdk.cairo_set_source_pixbuf (c, pixbuf, 1, 1);
        c.paint ();

        var pattern = new Cairo.Pattern.for_surface (surface);
        pattern.set_extend (Cairo.Extend.REPEAT);
        return pattern;
    }
    
    private Cairo.Pattern render_number_pattern (uint n)
    {
        var layout = create_pango_layout ("%u".printf (n));
        layout.set_alignment (Pango.Alignment.CENTER);

        /* set attributes for the layout */
        var attributes = new Pango.AttrList ();

        /* Color */
        Pango.Attribute color_attribute;
        switch (n)
        {
        case 1:
            color_attribute = Pango.attr_foreground_new (0x0000, 0x0000, 0xffff); /* Blue */
            break;
        case 2:
            color_attribute = Pango.attr_foreground_new (0x0000, 0xa0a0, 0x0000); /* Green */
            break;
        case 3:
            color_attribute = Pango.attr_foreground_new (0xffff, 0x0000, 0x0000); /* Red */
            break;
        case 4:
            color_attribute = Pango.attr_foreground_new (0x0000, 0x0000, 0x7fff); /* Dark Blue */
            break;
        case 5:
            color_attribute = Pango.attr_foreground_new (0xa0a0, 0x0000, 0x0000); /* Dark Red */
            break;
        case 6:
            color_attribute = Pango.attr_foreground_new (0x0000, 0xffff, 0xffff); /* Cyan */
            break;
        case 7:
            color_attribute = Pango.attr_foreground_new (0xa0a0, 0x0000, 0xa0a0); /* Dark Violet */
            break;
        default:
        case 8:
            color_attribute = Pango.attr_foreground_new (0x0000, 0x0000, 0x0000); /* Black */
            break;
        }
        color_attribute.start_index = 0;
        color_attribute.end_index = uint.MAX;
        attributes.insert ((owned) color_attribute);

        var font_desc = new Pango.FontDescription ();
        font_desc.set_family ("Sans");
        var font_size = (mine_size - 2) * Pango.SCALE * 0.85;
        font_desc.set_absolute_size (font_size);
        font_desc.set_weight (Pango.Weight.BOLD);
        var font_attribute = new Pango.AttrFontDesc (font_desc);
        font_attribute.start_index = 0;
        font_attribute.end_index = uint.MAX;
        attributes.insert ((owned) font_attribute);

        layout.set_attributes (attributes);

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, (int) mine_size, (int) mine_size);
        var c = new Cairo.Context (surface);
        Pango.Rectangle extent;
        layout.get_extents (null, out extent);
        var dx = ((int) mine_size - 2 - extent.width / Pango.SCALE) / 2 + 1;
        var dy = ((int) mine_size - 2 - extent.height / Pango.SCALE) / 2 + 1;
        c.move_to (dx, dy);
        Pango.cairo_show_layout (c, layout);

        var pattern = new Cairo.Pattern.for_surface (surface);
        pattern.set_extend (Cairo.Extend.REPEAT);
        return pattern;
    }

    public override void realize ()
    {
        set_realized (true);

        Gtk.Allocation allocation;
        get_allocation (out allocation);

        var attributes = Gdk.WindowAttr ();
        attributes.window_type = Gdk.WindowType.CHILD;
        attributes.x = allocation.x;
        attributes.y = allocation.y;
        attributes.width = allocation.width;
        attributes.height = allocation.height;
        attributes.wclass = Gdk.WindowWindowClass.OUTPUT;
        attributes.visual = get_visual ();
        attributes.event_mask = get_events ();
        attributes.event_mask |= Gdk.EventMask.EXPOSURE_MASK | Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.POINTER_MOTION_MASK;

        var window = new Gdk.Window (get_parent_window (), attributes, Gdk.WindowAttributesType.X | Gdk.WindowAttributesType.Y | Gdk.WindowAttributesType.VISUAL);
        set_window (window);
        window.set_user_data (this);

        var style = get_style ().attach (window);
        set_style (style);
        style.set_background (window, Gtk.StateType.ACTIVE);
    }

    /* The frame makes sure that the minefield is allocated the correct size */
    /* This is the standard allocate routine - it could be removed and the parents routine inherited */
    public override void size_allocate (Gtk.Allocation allocation)
    {
        set_allocation (allocation);
        if (get_realized ())
        {
            var width = minefield.width * mine_size;
            var height = minefield.height * mine_size;
            var x = allocation.x + (allocation.width - width) / 2;
            var y = allocation.y + (allocation.height - height) / 2;

            get_window ().move_resize ((int) x, (int) y, (int) width, (int) height);
        }
    }
    
    public override void get_preferred_width (out int minimum, out int natural)
    {
        minimum = natural = (int) (minefield.width * minimum_size);
    }

    public override void get_preferred_height (out int minimum, out int natural)
    {
        minimum = natural = (int) (minefield.height * minimum_size);
    }

    private void redraw_sector_cb (uint x, uint y)
    {
        queue_draw_area ((int) (x * mine_size), (int) (y * mine_size), (int) mine_size, (int) mine_size);
    }
    
    private void draw_square (Cairo.Context cr, uint x, uint y)
    {
        /* Work out if the cursor is being held down on this square */
        var is_down = x == selected_x && y == selected_y && minefield.get_flag (x, y) != FlagType.FLAG;
        if (selected_x >= 0 && minefield.is_cleared (selected_x, selected_y))
        {
            foreach (var neighbour in neighbour_map)
            {
                var nx = selected_x + neighbour.x;
                var ny = selected_y + neighbour.y;
                if (!minefield.is_location (nx, ny))
                    continue;
                if (x == nx && y == ny && minefield.get_flag (nx, ny) != FlagType.FLAG)
                    is_down = true;
            }
        }

        /* Draw grid on ocean floor */
        if (minefield.is_cleared (x, y))
        {
            Gtk.paint_box (get_style (), cr, is_down ? Gtk.StateType.ACTIVE : Gtk.StateType.NORMAL, Gtk.ShadowType.IN, this,
                           "button", (int) (x * mine_size), (int) (y * mine_size), (int) mine_size, (int) mine_size);

            /* Draw dotted border */
            if (y == 0)
            {
                cr.move_to (x * mine_size, 0);
                cr.line_to (x * mine_size + mine_size - 1, 0);
            }
            if (x == 0)
            {
                cr.move_to (0, y * mine_size);
                cr.line_to (0, y * mine_size + mine_size - 1);
            }
            cr.move_to (x * mine_size + mine_size - 1 + 0.5, y * mine_size + 0.5);
            cr.line_to (x * mine_size + mine_size - 1 + 0.5, y * mine_size + mine_size - 1 + 0.5);
            cr.move_to (x * mine_size + 0.5, y * mine_size + mine_size - 1 + 0.5);
            cr.line_to (x * mine_size + mine_size - 1 + 0.5, y * mine_size + mine_size - 1 + 0.5);
            cr.save ();
            Gdk.cairo_set_source_color (cr, get_style ().dark[get_state ()]);
            cr.set_line_width (1);
            double[] dots = {2, 2};
            cr.set_dash (dots, 0);
            cr.stroke ();
            cr.restore ();

            /* Draw explosion if have uncovered a mine */
            if (minefield.has_mine (x, y))
            {
                if (bang_pattern == null)
                    bang_pattern = render_preimage_pattern (bang_preimage);
                cr.set_source (bang_pattern);
                cr.rectangle (x * mine_size, y * mine_size, mine_size, mine_size);
                cr.fill ();
            }
            /* Indicate the number of mines around this location */
            else
            {
                /* Warn if more flags than the number of mines available */
                if (use_overmine_warning && minefield.has_flag_warning (x, y))
                {
                    if (warning_pattern == null)
                        warning_pattern = render_preimage_pattern (warning_preimage);
                    cr.set_source (warning_pattern);
                    cr.rectangle (x * mine_size, y * mine_size, mine_size, mine_size);
                    cr.fill ();
                }

                var n = minefield.get_n_adjacent_mines (x, y);
                if (n != 0)
                {
                    if (number_patterns[n-1] == null)
                        number_patterns[n-1] = render_number_pattern (n);
                    cr.set_source (number_patterns[n-1]);
                    cr.rectangle (x * mine_size, y * mine_size, mine_size, mine_size);
                    cr.fill ();
                }
            }
        }
        else
        {
            /* Draw shadow around possible mine location */
            Gtk.paint_box (get_style (), cr,
                           is_down ? Gtk.StateType.ACTIVE : Gtk.StateType.SELECTED,
                           is_down ? Gtk.ShadowType.IN : Gtk.ShadowType.OUT,
                           this,
                           "button", (int) (x * mine_size), (int) (y * mine_size), (int) mine_size, (int) mine_size);

            /* Draw flags on uncleared locations */
            if (minefield.get_flag (x, y) == FlagType.FLAG)
            {
                if (flag_pattern == null)
                    flag_pattern = render_preimage_pattern (flag_preimage);                    
                cr.set_source (flag_pattern);
                cr.rectangle (x * mine_size, y * mine_size, mine_size, mine_size);
                cr.fill ();

                /* Cross out incorrect flags */
                if (minefield.exploded && !minefield.has_mine (x, y))
                {
                    var x1 = x * mine_size + 0.1 * mine_size;
                    var y1 = y * mine_size + 0.1 * mine_size;
                    var x2 = x * mine_size + 0.9 * mine_size;
                    var y2 = y * mine_size + 0.9 * mine_size;

                    cr.move_to (x1, y1);
                    cr.line_to (x2, y2);
                    cr.move_to (x1, y2);
                    cr.line_to (x2, y1);

                    cr.save ();
                    Gdk.cairo_set_source_color (cr, get_style ().black);
                    cr.set_line_width (double.max (1, 0.1 * mine_size));
                    cr.set_line_join (Cairo.LineJoin.ROUND);
                    cr.set_line_cap (Cairo.LineCap.ROUND);
                    cr.stroke ();
                    cr.restore ();
                }
            }
            else if (minefield.exploded && minefield.has_mine (x, y))
            {
                if (mine_pattern == null)
                    mine_pattern = render_preimage_pattern (mine_preimage);
                cr.set_source (mine_pattern);
                cr.rectangle (x * mine_size, y * mine_size, mine_size, mine_size);
                cr.fill ();
            }
            else if (minefield.get_flag (x, y) == FlagType.MAYBE)
            {
                if (question_pattern == null)
                    question_pattern = render_preimage_pattern (question_preimage);
                cr.set_source (question_pattern);
                cr.rectangle (x * mine_size, y * mine_size, mine_size, mine_size);
                cr.fill ();
            }
        }
    }

    public override bool draw (Cairo.Context cr)
    {
        /* Resize images */
        if (render_size != mine_size)
        {
            render_size = mine_size;
            flag_pattern = null;
            mine_pattern = null;
            question_pattern = null;
            bang_pattern = null;
            warning_pattern = null;
            for (var i = 0; i < number_patterns.length; i++)
                number_patterns[i] = null;
        }

        for (var x = 0; x < minefield.width; x++)
            for (var y = 0; y < minefield.height; y++)
                draw_square (cr, x, y);

        return false;
    }

    private void toggle_mark (uint x, uint y)
    {
        switch (minefield.get_flag (x, y))
        {
        case FlagType.NONE:
            /* If we've used all the flags don't plant any more,
             * this should be an indication to the player that they
             * have made a mistake. */
            if (minefield.n_flags >= minefield.n_mines && use_question_marks)
                minefield.set_flag (x, y, FlagType.MAYBE);
            else
                minefield.set_flag (x, y, FlagType.FLAG);
            break;

        case FlagType.MAYBE:
            minefield.set_flag (x, y, FlagType.NONE);
            break;

        case FlagType.FLAG:
            if (use_question_marks)
                minefield.set_flag (x, y, FlagType.MAYBE);
            else
                minefield.set_flag (x, y, FlagType.NONE);
            break;
        }
    }

    private void redraw_adjacent (uint x, uint y)
    {
        foreach (var neighbour in neighbour_map)
        {
            var nx = x + neighbour.x;
            var ny = y + neighbour.y;
            if (minefield.is_location (nx, ny))
                redraw_sector_cb (nx, ny);
        }
    }

    private void multi_release (uint x, uint y)
    {
        if (!minefield.is_cleared (x, y) || minefield.get_flag (x, y) == FlagType.FLAG)
            return;

        /* Work out how many flags / unknown squares surround this one */
        var n_mines = minefield.get_n_adjacent_mines (x, y);
        uint n_flags = 0;
        uint n_unknown = 0;
        foreach (var neighbour in neighbour_map)
        {
            var nx = x + neighbour.x;
            var ny = y + neighbour.y;
            if (!minefield.is_location (nx, ny))
                continue;
            if (minefield.get_flag (nx, ny) == FlagType.FLAG)
                n_flags++;
            if (!minefield.is_cleared (nx, ny))
                n_unknown++;
        }

        /* If have correct number of flags to mines then clear the other
         * locations, otherwise if the number of unknown squares is the
         * same as the number of mines flag them all */
        var do_clear = false;
        if (n_mines == n_flags)
            do_clear = true;
        else if (use_autoflag && n_unknown == n_mines)
            do_clear = false;        
        else
            return;

        /* Use the same minefield for the whole time (it may complete as we do it) */
        var m = minefield;

        foreach (var neighbour in neighbour_map)
        {
            var nx = x + neighbour.x;
            var ny = y + neighbour.y;
            if (!m.is_location (nx, ny))
                continue;
            
            if (do_clear && m.get_flag (nx, ny) != FlagType.FLAG)
                m.clear_mine (nx, ny);
            else
                m.set_flag (nx, ny, FlagType.FLAG);
        }
    }

    public override bool button_press_event (Gdk.EventButton event)
    {
        /* Ignore double click events */
        if (event.type != Gdk.EventType.BUTTON_PRESS)
            return false;
            
        if (minefield.exploded || minefield.is_complete)
            return false;

        var x = (int) (event.x / mine_size);
        var y = (int) (event.y / mine_size);
        if (!minefield.is_location (x, y))
            return false;

        /* Right or Ctrl+Left button to toggle flags */
        if (event.button == 3 || (event.button == 1 && (event.state & Gdk.ModifierType.CONTROL_MASK) != 0))
        {
            toggle_mark (x, y);
            return false;
        }

        /* Left button to clear */
        if (event.button == 1)
        {
            selected_x = x;
            selected_y = y;
            redraw_sector_cb (x, y);

            look ();

            if (minefield.is_cleared (x, y))
                redraw_adjacent (x, y);
        }

        return false;
    }

    public override bool motion_notify_event (Gdk.EventMotion event)
    {
        if (minefield.exploded || minefield.is_complete)
            return false;
            
        if (selected_x < 0)
            return false;

        var x = (int) (event.x / mine_size);
        var y = (int) (event.y / mine_size);
        if (!minefield.is_location (x, y))
            return false;

        if (x == selected_x && y == selected_y)
            return false;

        /* Redraw existing selected squares */
        redraw_sector_cb (selected_x, selected_y);
        if (minefield.is_cleared (selected_x, selected_y))
            redraw_adjacent (selected_x, selected_y);

        /* Draw new selected squares */
        redraw_sector_cb (x, y);
        if (minefield.is_cleared (x, y))
            redraw_adjacent (x, y);

        selected_x = x;
        selected_y = y;

        return false;
    }

    public override bool button_release_event (Gdk.EventButton event)
    {
        if (minefield.exploded || minefield.is_complete)
            return false;

        if (selected_x < 0)
            return false;

        if (event.button == 1)
        {
            unlook ();

            if (minefield.is_cleared (selected_x, selected_y))
            {
                multi_release (selected_x, selected_y);
                redraw_adjacent (selected_x, selected_y);
            }
            else if (minefield.get_flag (selected_x, selected_y) != FlagType.FLAG)
                minefield.clear_mine (selected_x, selected_y);
            redraw_sector_cb (selected_x, selected_y);
        }

        selected_x = -1;
        selected_y = -1;

        return false;
    }
}
