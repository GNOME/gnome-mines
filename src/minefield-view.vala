/*
 * Copyright (C) 2011-2012 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

private class Position : Object
{
    public signal void redraw (uint x, uint y);
    public signal bool validate (int x, int y);
    public signal int set_x (int x);
    public signal int set_y (int y);

    private bool _is_set = false;
    public bool is_set
    {
        get { return _is_set; }
        set
        {
            if (_is_set != value && is_valid)
                redraw (x, y);

            _is_set = value;
        }
    }

    public bool is_valid
    {
        get { return validate (x, y); }
    }

    private int _x = 0;
    public int x
    {
        get { return _x; }
        set
        {
            if (_x == value)
                return;

            if (is_set && is_valid)
                redraw (x, y);

            _x = set_x (value);

            if (is_set && is_valid)
                redraw (x, y);
        }
    }

    private int _y = 0;
    public int y
    {
        get { return _y; }
        set
        {
            if (_y == value)
                return;

            if (is_set && is_valid)
                redraw (x, y);

            _y = set_y (value);

            if (is_set && is_valid)
                redraw (x, y);
        }
    }

    public int[] position
    {
        set
        {
            if (_x == value[0] && _y == value[1])
                return;

            if (is_set && is_valid)
                redraw (x, y);

            _x = set_x (value[0]);
            _y = set_y (value[1]);

            if (is_set && is_valid)
                redraw (x, y);
        }
    }
}

public class MinefieldView : Gtk.DrawingArea
{
    /* true if allowed to mark locations with question marks */
    private bool use_question_marks;

    /* true if should warn when too many flags set */
    private bool use_overmine_warning;

    /* true if automatically set flags on middle click */
    private bool use_autoflag;

    /* Position of keyboard cursor and selected squares */
    private Position keyboard_cursor;
    private Position selected;

    /* true if numbers should be drawn with border */
    private bool use_number_border;

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
    
    private uint x_offset
    {
        get
        {
            return (get_allocated_width () - minefield.width * mine_size) / 2;
        }
    }

    private uint y_offset
    {
        get
        {
            return (get_allocated_height () - minefield.height * mine_size) / 2;
        }
    }

    private uint minimum_size
    {
        get
        {
            var w = 320 / minefield.width;
            var h = 200 / minefield.height;
            var s = uint.min (w, h);
            if (s < 30)
                s = 30;
            return s;
        }
    }

    public signal void look ();
    public signal void unlook ();

    public MinefieldView ()
    {
        set_events (Gdk.EventMask.EXPOSURE_MASK | Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);
        can_focus = true;
        selected = new Position ();
        keyboard_cursor = new Position ();
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

            selected.is_set = false;
            selected.redraw.connect (redraw_sector_cb);
            selected.redraw.connect ((x, y) => { if (_minefield.is_cleared (x, y)) redraw_adjacent (x, y); });
            selected.set_x.connect ((x) => { return x; });
            selected.set_y.connect ((y) => { return y; });
            selected.validate.connect (_minefield.is_location);

            keyboard_cursor.is_set = false;
            keyboard_cursor.position = {0, 0};
            keyboard_cursor.redraw.connect (redraw_sector_cb);
            keyboard_cursor.set_x.connect ((x) => { return (int) (x % _minefield.width); });
            keyboard_cursor.set_y.connect ((y) => { return (int) (y % _minefield.height); });
            keyboard_cursor.validate.connect ((x, y) => { return true; });

            _minefield.redraw_sector.connect (redraw_sector_cb);
            _minefield.explode.connect (explode_cb);
            _minefield.paused_changed.connect (() => { queue_draw (); });

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

    public void set_use_number_border (bool use_number_border)
    {
        if (this.use_number_border != use_number_border)
            render_size = 0;

        this.use_number_border = use_number_border;
    }

    private void explode_cb (Minefield minefield)
    {
        /* Show the mines that we missed or the flags that were wrong */
        for (var x = 0; x < minefield.width; x++)
            for (var y = 0; y < minefield.height; y++)
                if (minefield.has_mine (x, y) || (!minefield.has_mine (x, y) && minefield.get_flag (x, y) == FlagType.FLAG))
                    redraw_sector_cb (x, y);
    }

    private Cairo.Pattern render_svg_pattern (Cairo.Context cr, string filename)
    {
        var surface = new Cairo.Surface.similar (cr.get_target (), Cairo.Content.COLOR_ALPHA, (int) mine_size, (int) mine_size); 
        var c = new Cairo.Context (surface);
        Gdk.Pixbuf pixbuf;
        var size = (int) mine_size - 2;
        try
        {
            pixbuf = Rsvg.pixbuf_from_file_at_size (filename, size, size);
        }
        catch (Error e)
        {
            pixbuf = new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8, size, size);
        }
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
        double color_outline[3];
        switch (n)
        {
        case 1:
            color_attribute = Pango.attr_foreground_new (0x0000, 0x0000, 0xffff); /* Blue */
            color_outline = {0.0, 0.0, 0.5};
            break;
        case 2:
            color_attribute = Pango.attr_foreground_new (0x0000, 0xa0a0, 0x0000); /* Green */
            color_outline = {0.0, 0.5*0.62745098039, 0.0};
            break;
        case 3:
            color_attribute = Pango.attr_foreground_new (0xffff, 0x0000, 0x0000); /* Red */
            color_outline = {0.5, 0.0, 0.0};
            break;
        case 4:
            color_attribute = Pango.attr_foreground_new (0x0000, 0x0000, 0x7fff); /* Dark Blue */
            color_outline = {0.0, 0.0, 0.5*0.49999237048};
            break;
        case 5:
            color_attribute = Pango.attr_foreground_new (0xa0a0, 0x0000, 0x0000); /* Dark Red */
            color_outline = {0.5*0.62745098039, 0.0, 0.0};
            break;
        case 6:
            color_attribute = Pango.attr_foreground_new (0x0000, 0xffff, 0xffff); /* Cyan */
            color_outline = {0.0, 0.5, 0.5};
            break;
        case 7:
            color_attribute = Pango.attr_foreground_new (0xa0a0, 0x0000, 0xa0a0); /* Dark Violet */
            color_outline = {0.5*0.62745098039, 0.0, 0.5*0.62745098039};
            break;
        default:
        case 8:
            color_attribute = Pango.attr_foreground_new (0x0000, 0x0000, 0x0000); /* Black */
            color_outline = {0.0, 0.0, 0.0};
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

        if (use_number_border)
        {
            c.save ();
            c.set_line_width(1.0);
            c.set_source_rgb(color_outline[0],
                             color_outline[1],
                             color_outline[2]);
            Pango.cairo_layout_path(c, layout);
            c.stroke_preserve();
            c.restore ();
        }

        var pattern = new Cairo.Pattern.for_surface (surface);
        pattern.set_extend (Cairo.Extend.REPEAT);
        return pattern;
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
        queue_draw_area ((int) (x_offset + x * mine_size), (int) (y_offset + y * mine_size), (int) mine_size, (int) mine_size);
    }
    
    private void draw_square (Cairo.Context cr, uint x, uint y)
    {
        /* Work out if the cursor is being held down on this square or neighbouring cleared squares */
        var is_down = false;
        if (selected.is_valid && selected.is_set)
        {
            is_down = x == selected.x && y == selected.y && minefield.get_flag (x, y) != FlagType.FLAG;
            if (!is_down && minefield.is_cleared (selected.x, selected.y))
            {
                foreach (var neighbour in neighbour_map)
                {
                    var nx = (int) selected.x + neighbour.x;
                    var ny = (int) selected.y + neighbour.y;
                    if (!minefield.is_location (nx, ny))
                        continue;
                    if (x == nx && y == ny && minefield.get_flag (nx, ny) != FlagType.FLAG)
                        is_down = true;
                }
            }
        }

        /* Draw grid on ocean floor */
        if (minefield.is_cleared (x, y))
        {
            if (minefield.paused)
                return;

            /* Draw explosion if have uncovered a mine */
            if (minefield.has_mine (x, y))
            {
                if (bang_pattern == null)
                    bang_pattern = render_svg_pattern (cr, Path.build_filename (DATA_DIRECTORY, "bang.svg"));
                cr.set_source (bang_pattern);
                cr.rectangle (0, 0, mine_size, mine_size);
                cr.fill ();
            }
            /* Indicate the number of mines around this location */
            else
            {
                /* Warn if more flags than the number of mines available */
                if (use_overmine_warning && minefield.has_flag_warning (x, y))
                {
                    if (warning_pattern == null)
                        warning_pattern = render_svg_pattern (cr, Path.build_filename (DATA_DIRECTORY, "warning.svg"));
                    cr.set_source (warning_pattern);
                    cr.rectangle (0, 0, mine_size, mine_size);
                    cr.fill ();
                }

                var n = minefield.get_n_adjacent_mines (x, y);
                if (n != 0)
                {
                    if (number_patterns[n-1] == null)
                        number_patterns[n-1] = render_number_pattern (n);
                    cr.set_source (number_patterns[n-1]);
                    cr.rectangle (0, 0, mine_size, mine_size);
                    cr.fill ();
                }
            }
        }
        else
        {
            var style_context = get_style_context ();
            style_context.save ();
            style_context.add_class (Gtk.STYLE_CLASS_BUTTON);
            style_context.set_state (is_down ? Gtk.StateFlags.ACTIVE : Gtk.StateFlags.NORMAL);
            style_context.render_frame (cr, 0, 0, (int) mine_size, (int) mine_size);
            style_context.render_background (cr, 0, 0, (int) mine_size, (int) mine_size);
            style_context.restore ();

            if (minefield.paused)
                return;

            /* Draw flags on uncleared locations */
            if (minefield.get_flag (x, y) == FlagType.FLAG)
            {
                if (flag_pattern == null)
                    flag_pattern = render_svg_pattern (cr, Path.build_filename (DATA_DIRECTORY, "flag.svg"));                    
                cr.set_source (flag_pattern);
                cr.rectangle (0, 0, mine_size, mine_size);
                cr.fill ();

                /* Cross out incorrect flags */
                if (minefield.exploded && !minefield.has_mine (x, y))
                {
                    var x1 = 0.1 * mine_size;
                    var y1 = 0.1 * mine_size;
                    var x2 = 0.9 * mine_size;
                    var y2 = 0.9 * mine_size;

                    cr.move_to (x1, y1);
                    cr.line_to (x2, y2);
                    cr.move_to (x1, y2);
                    cr.line_to (x2, y1);

                    cr.save ();
                    cr.set_source_rgba (0.0, 0.0, 0.0, 1.0);
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
                    mine_pattern = render_svg_pattern (cr, Path.build_filename (DATA_DIRECTORY, "mine.svg"));
                cr.set_source (mine_pattern);
                cr.rectangle (0, 0, mine_size, mine_size);
                cr.fill ();
            }
            else if (minefield.get_flag (x, y) == FlagType.MAYBE)
            {
                if (question_pattern == null)
                    question_pattern = render_svg_pattern (cr, Path.build_filename (DATA_DIRECTORY, "flag-question.svg"));
                cr.set_source (question_pattern);
                cr.rectangle (0, 0, mine_size, mine_size);
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

        double dimensions[2] = {minefield.width * mine_size, minefield.height * mine_size};
        double centre[2] = { x_offset + 0.5 * dimensions[0], y_offset + 0.5 * dimensions[1] };
        double radius = Math.fmax (dimensions[0], dimensions[1]);

        /* Draw Background */
        var pattern = new Cairo.Pattern.radial (centre[0], centre[1], 0.0, centre[0], centre[1], radius);
        pattern.add_color_stop_rgba (0.0, 0.0, 0.0, 0.0, 0.1);
        pattern.add_color_stop_rgba (1.0, 0.0, 0.0, 0.0, 0.4);

        cr.rectangle (x_offset - 0.5, y_offset - 0.5, dimensions[0] + 0.5, dimensions[1] + 0.5);
        cr.save ();
        cr.set_source (pattern);
        cr.fill_preserve ();
        cr.set_line_width (0.5);
        cr.set_source_rgba (0.0, 0.0, 0.0, 1.0);
        cr.stroke ();
        cr.restore ();

        /* Draw Grid */
        cr.save ();
        cr.set_line_width (0.5);
        cr.set_source_rgba (0.0, 0.0, 0.0, 1.0);
        double[] dots = {2, 2};
        cr.set_dash (dots, 0);

        for (var x = 1; x < minefield.width; x++)
        {
            cr.move_to (x_offset + x * mine_size, y_offset);
            cr.line_to (x_offset + x * mine_size, y_offset + dimensions[1]);
            cr.stroke ();
        }

        for (var y = 1; y < minefield.height; y++)
        {
            cr.move_to (x_offset, y_offset + y * mine_size);
            cr.line_to (x_offset + dimensions[0], y_offset + y * mine_size);
            cr.stroke ();
        }

        cr.restore ();

        /* Draw Minefield */
        for (var x = 0; x < minefield.width; x++)
        {
            for (var y = 0; y < minefield.height; y++)
            {
                cr.save ();
                cr.translate (x_offset + x * mine_size, y_offset + y * mine_size);
                draw_square (cr, x, y);
                cr.restore ();
            }
        }

        /* Draw keyboard cursor */
        if (keyboard_cursor.is_set)
        {
            double key_centre[2] = { x_offset + (keyboard_cursor.x+0.5) * mine_size, y_offset + (keyboard_cursor.y+0.5) * mine_size };
            var key_cursor = new Cairo.Pattern.radial (key_centre[0], key_centre[1], 0.0, key_centre[0], key_centre[1], 0.25 * mine_size);
            key_cursor.add_color_stop_rgba (0.0, 1.0, 1.0, 1.0, 1.0);
            key_cursor.add_color_stop_rgba (0.8, 1.0, 1.0, 1.0, 0.1);
            key_cursor.add_color_stop_rgba (0.9, 0.0, 0.0, 0.0, 0.5);
            key_cursor.add_color_stop_rgba (1.0, 0.0, 0.0, 0.0, 0.2);
            key_cursor.add_color_stop_rgba (1.0, 0.0, 0.0, 0.0, 0.0);

            cr.save ();
            cr.rectangle (key_centre[0] - 0.45 * mine_size, key_centre[1] - 0.45 * mine_size, 0.9 * mine_size, 0.9 * mine_size);
            cr.set_source (key_cursor);
            cr.fill ();
            cr.restore ();
        }

        /* Draw pause overlay */
        if (minefield.paused)
        {
            cr.set_source_rgba (0, 0, 0, 0.75);
            cr.paint ();

            cr.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
            cr.set_font_size (get_allocated_width () * 0.125);

            var text = _("Paused");
            Cairo.TextExtents extents;
            cr.text_extents (text, out extents);
            cr.move_to ((get_allocated_width () - extents.width) / 2.0, (get_allocated_height () + extents.height) / 2.0);
            cr.set_source_rgb (1, 1, 1);
            cr.show_text (text);
        }

        return false;
    }

    private void toggle_mark (uint x, uint y)
    {
        if (minefield.is_cleared (x, y))
            return;

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
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
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
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
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
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
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

        /* Check for end cases and paused game */
        if (minefield.exploded || minefield.is_complete || minefield.paused)
            return false;

        /* Does the user have the space key down? */
        if (selected.is_set && keyboard_cursor.is_set)
            return false;

        /* Hide any lingering previously selected and get new location */
        selected.is_set = false;
        selected.x = (int) Math.floor ((event.x - x_offset) / mine_size);
        selected.y = (int) Math.floor ((event.y - y_offset) / mine_size);

        /* Is the current position a minefield square? */
        if (!selected.is_valid)
            return false;

        /* Right or Ctrl+Left button to toggle flags */
        if (event.button == 3 || (event.button == 1 && (event.state & Gdk.ModifierType.CONTROL_MASK) != 0))
        {
            toggle_mark (selected.x, selected.y);
            unlook ();
        }
        /* Left button to clear */
        else if (event.button == 1)
        {
            selected.is_set = true;
            look ();
        }

        keyboard_cursor.is_set = false;
        keyboard_cursor.position = {selected.x, selected.y};

        return false;
    }

    public override bool motion_notify_event (Gdk.EventMotion event)
    {
        /* Check for end cases and paused game */
        if (minefield.exploded || minefield.is_complete || minefield.paused)
            return false;

        /* Check that the user isn't currently navigating with keyboard */
        if (!selected.is_set || keyboard_cursor.is_set)
            return false;

        var x = (int) Math.floor ((event.x - x_offset) / mine_size);
        var y = (int) Math.floor ((event.y - y_offset) / mine_size);
        selected.position = {x, y};

        return false;
    }

    public override bool button_release_event (Gdk.EventButton event)
    {
        if (event.button != 1)
            return false;

        /* Check for end cases and paused game */
        if (minefield.exploded || minefield.is_complete || minefield.paused)
            return false;

        /* Check that the user isn't currently using the mouse */
        if (!selected.is_set || keyboard_cursor.is_set)
            return false;

        /* Check if the user released button outside the minefield */
        if (!minefield.is_location(selected.x, selected.y))
            return false;

        unlook ();

        if (minefield.is_cleared (selected.x, selected.y))
        {
            multi_release (selected.x, selected.y);
            redraw_adjacent (selected.x, selected.y);
        }
        else if (minefield.get_flag (selected.x, selected.y) != FlagType.FLAG)
            minefield.clear_mine (selected.x, selected.y);

        keyboard_cursor.position = {selected.x, selected.y};
        selected.is_set = false;

        return false;
    }

    public override bool key_press_event (Gdk.EventKey event)
    {
        /* Check for end cases and paused game */
        if (minefield.exploded || minefield.is_complete || minefield.paused)
            return false;

        /* Check that the user isn't currently using the mouse */
        if (selected.is_set && !keyboard_cursor.is_set)
            return false;

        var x = keyboard_cursor.x;
        var y = keyboard_cursor.y;

        switch (event.keyval)
        {
        case Gdk.Key.Left:
        case Gdk.Key.h:
            x--;
            break;

        case Gdk.Key.Right:
        case Gdk.Key.l:
            x++;
            break;

        case Gdk.Key.Up:
        case Gdk.Key.k:
            y--;
            break;

        case Gdk.Key.Down:
        case Gdk.Key.j:
            y++;
            break;

        case Gdk.Key.space:
        case Gdk.Key.Return:
            if (keyboard_cursor.is_set)
            {
                selected.is_set = false;

                if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)
                {
                    toggle_mark (keyboard_cursor.x, keyboard_cursor.y);
                }
                else
                {
                    selected.position = {x, y};
                    selected.is_set = true;
                    look ();
                }
            }
            break;

        default:
            return false;
        }

        if (x == keyboard_cursor.x && y == keyboard_cursor.y)
            return true;

        if (!keyboard_cursor.is_set)
        {
            keyboard_cursor.is_set = true;
            return true;
        }

        keyboard_cursor.position = {x, y};

        if (selected.is_set)
            selected.position = {keyboard_cursor.x, keyboard_cursor.y};

        return true;
    }

    public override bool key_release_event (Gdk.EventKey event)
    {
        if (event.keyval != Gdk.Key.space)
            return false;

        /* Check for end cases and paused game */
        if (minefield.exploded || minefield.is_complete || minefield.paused)
            return false;

        /* Check that the user isn't currently using the mouse */
        if (!selected.is_set || !keyboard_cursor.is_set)
            return false;

        unlook ();

        if (minefield.is_cleared (selected.x, selected.y))
        {
            multi_release (selected.x, selected.y);
            redraw_adjacent (selected.x, selected.y);
        }
        else if (minefield.get_flag (selected.x, selected.y) != FlagType.FLAG)
            minefield.clear_mine (selected.x, selected.y);

        selected.is_set = false;

        return false;
    }
}
