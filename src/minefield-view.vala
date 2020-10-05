/*
 * Copyright (C) 2011-2012 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
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

public class MinefieldView : Gtk.Grid
{
    private Settings settings;
    private bool force_nolongpress;

    /* true if allowed to mark locations with question marks */
    private bool use_question_marks
    {
        get
        {
            return settings.get_boolean (Mines.KEY_USE_QUESTION_MARKS);
        }
    }

    /* true if automatically set flags on middle click... for debugging */
    private bool use_autoflag
    {
        get
        {
            return settings.get_boolean (Mines.KEY_USE_AUTOFLAG);
        }
    }

    /* Position of keyboard cursor and selected squares */
    private Position keyboard_cursor;
    private Position selected;

    private Tile[,] mines;

    public uint mine_size
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

    private Gtk.EventControllerKey key_controller;    // for keeping in memory

    construct
    {
        init_keyboard ();
    }

    public MinefieldView (Settings settings)
    {
        this.settings = settings;
        this.force_nolongpress = false;
        row_homogeneous = true;
        row_spacing = 0;
        column_homogeneous = true;
        column_spacing = 0;
        set_events (Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);
        can_focus = true;
        expand = true;
        get_style_context ().add_class ("minefield");

        selected = new Position ();
        selected.set_x.connect ((x) => { return x; });
        selected.set_y.connect ((y) => { return y; });
        selected.redraw.connect (redraw_sector_cb);

        keyboard_cursor = new Position ();
        keyboard_cursor.redraw.connect (redraw_sector_cb);
        keyboard_cursor.validate.connect ((x, y) => { return true; });
    }

    private Minefield _minefield;
    public Minefield minefield
    {
        get { return _minefield; }
        set
        {
            if (_minefield != null)
            {
                SignalHandler.disconnect_by_func (_minefield, null, this);
            }
            _minefield = value;
            get_style_context ().remove_class ("explodedField");
            get_style_context ().remove_class ("completedField");
            mines = new Tile[_minefield.width, _minefield.height];
            forall ((child) => { remove (child); });
            for (int i = 0; i < _minefield.width; i++)
            {
                for (int j = 0; j < _minefield.height; j++)
                {
                    mines[i,j] = new Tile (i, j);
                    mines[i,j].show ();
                    mines[i,j].tile_pressed.connect ((x, y, event) => { tile_pressed_cb (x, y, event); });
                    mines[i,j].tile_released.connect ((x, y, event) => { tile_released_cb (x, y, event); });
                    mines[i,j].tile_long_pressed.connect ((x, y) => { tile_long_pressed_cb (x, y); });
                    add (mines[i,j], i, j);
                }
            }
            selected.is_set = false;

            selected.validate.connect (_minefield.is_location);

            keyboard_cursor.is_set = false;
            keyboard_cursor.position = {0, 0};
            keyboard_cursor.set_x.connect ((x) => { return x; }); // (int) (x % _minefield.width); });
            keyboard_cursor.set_y.connect ((y) => { return y; }); // (int) (y % _minefield.height); });

            _minefield.redraw_sector.connect (redraw_sector_cb);
            _minefield.explode.connect (explode_cb);
            _minefield.cleared.connect (complete_cb);
            _minefield.use_autoflag = use_autoflag;
            queue_resize ();
        }
    }

    public void tile_pressed_cb (int x, int y, Gdk.EventButton event)
    {
        /* Ignore double click events */
        if (event.type != Gdk.EventType.BUTTON_PRESS)
            return;

        /* Check for end cases and paused game */
        if (minefield.exploded || minefield.is_complete || minefield.paused)
            return;

        /* Does the user have the space key down? */
        if (selected.is_set && keyboard_cursor.is_set)
            return;

        /* Hide any lingering previously selected and get new location */
        selected.is_set = false;
        selected.position = {x, y};

        /* Is the current position a minefield square? */
        if (!selected.is_valid)
            return;

        /* Right or Ctrl+Left button to toggle flags */
        if (event.button == 3 || (event.button == 1 && (event.state & Gdk.ModifierType.CONTROL_MASK) != 0))
        {
            toggle_mark (selected.x, selected.y);
            this.force_nolongpress = true;
        }
        else
        {
            selected.is_set = true;
        }

        keyboard_cursor.is_set = false;
        mines[keyboard_cursor.x,keyboard_cursor.y].remove_class ("cursor");
        keyboard_cursor.position = {selected.x, selected.y};
    }

    public void tile_released_cb (int x, int y, Gdk.EventButton event)
    {
        if (event.button != 1) return;

        this.force_nolongpress = false;

        /* Check for end cases and paused game */
        if (minefield.exploded || minefield.is_complete || minefield.paused)
            return;

        /* Check that the user isn't currently using the mouse */
        if (!selected.is_set || keyboard_cursor.is_set)
            return;

        /* Check if the square released is the sames as the square pressed. */
        if (selected.x != x || selected.y != y)
            return;

        /* Check if the user released button outside the minefield */
        if (!minefield.is_location (selected.x, selected.y))
            return;

        if (minefield.is_cleared (selected.x, selected.y))
            minefield.multi_release (selected.x, selected.y);
        else if (minefield.get_flag (selected.x, selected.y) != FlagType.FLAG)
            minefield.clear_mine (selected.x, selected.y);

        keyboard_cursor.position = {selected.x, selected.y};
        selected.is_set = false;
    }

    public void tile_long_pressed_cb (int x, int y)
    {
        if (this.force_nolongpress == true) return;
        selected.is_set = false;
        toggle_mark (selected.x, selected.y);
    }

    private void explode_cb (Minefield minefield)
    {
        get_style_context  ().add_class ("explodedField");
        /* Show the mines that we missed or the flags that were wrong */
        for (var x = 0; x < minefield.width; x++)
            for (var y = 0; y < minefield.height; y++)
            {
                if (minefield.has_mine (x, y) || (!minefield.has_mine (x, y) && minefield.get_flag (x, y) == FlagType.FLAG))
                    redraw_sector_cb (x, y);
            }
    }

    private void complete_cb (Minefield minefield)
    {
        get_style_context  ().add_class ("completedField");
    }

    public override void get_preferred_width (out int minimum, out int natural)
    {
        minimum = natural = minefield != null ? (int) (minefield.width * minimum_size) : 0;
    }

    public override void get_preferred_height (out int minimum, out int natural)
    {
        minimum = natural = minefield != null ? (int) (minefield.height * minimum_size) : 0;
    }

    public new void add (Gtk.Widget child, int i, int j)
    {
        attach (child, i-1, j-1, 1, 1);
        child.expand = true;
    }

    private void redraw_sector_cb (uint x, uint y)
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
                mines[x,y].add_class ("exploded");
            }
            /* Indicate the number of mines around this location */
            else
            {
                var n = minefield.get_n_adjacent_mines (x, y);
                mines[x,y].remove_class ("maybe");
                mines[x,y].remove_class ("flag");
                mines[x,y].add_class ("count");
                if (n > 0)
                    mines[x,y].add_class ("%umines".printf (n));
            }
        }
        else
        {
            if (minefield.paused)
                return;

            /* Draw flags on uncleared locations */
            if (minefield.get_flag (x, y) == FlagType.FLAG)
            {
                mines[x,y].add_class ("flag");
                /* Cross out incorrect flags */
                if (minefield.exploded && !minefield.has_mine (x, y))
                {
                    mines[x,y].add_class ("incorrect");
                }
            }
            else if (minefield.exploded && minefield.has_mine (x, y))
            {
                mines[x,y].add_class ("mine");
            }

        }
    }

    public void toggle_mark (uint x, uint y)
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
            {
                minefield.set_flag (x, y, FlagType.MAYBE);
                mines[x,y].add_class ("maybe");
            }
            else
            {
                minefield.set_flag (x, y, FlagType.FLAG);
                mines[x,y].add_class ("flag");
            }
            break;

        case FlagType.MAYBE:
            mines[x,y].remove_class ("maybe");
            minefield.set_flag (x, y, FlagType.NONE);
            break;

        case FlagType.FLAG:
            mines[x,y].remove_class ("flag");
            if (use_question_marks)
            {
                minefield.set_flag (x, y, FlagType.MAYBE);
                mines[x,y].add_class ("maybe");
            }
            else
            {
                minefield.set_flag (x, y, FlagType.NONE);
            }
            break;
        }
    }

    private inline void init_keyboard ()  // called on construct
    {
        key_controller = new Gtk.EventControllerKey (this);
        key_controller.key_pressed.connect (on_key_pressed);
        key_controller.key_released.connect (on_key_released);
    }

    private inline bool on_key_pressed (Gtk.EventControllerKey _key_controller, uint keyval, uint keycode, Gdk.ModifierType state)
    {
        /* Check for end cases and paused game */
        if (minefield.exploded || minefield.is_complete || minefield.paused)
            return false;

        /* Check that the user isn't currently using the mouse */
        if (selected.is_set && !keyboard_cursor.is_set)
            return false;

        var x = keyboard_cursor.x;
        var y = keyboard_cursor.y;
        mines[keyboard_cursor.x,keyboard_cursor.y].remove_class ("cursor");

        switch (keyval)
        {
        case Gdk.Key.Left:
        case Gdk.Key.h:
            x--;
            break;

        case Gdk.Key.Right:
        case Gdk.Key.k:
            x++;
            break;

        case Gdk.Key.Up:
        case Gdk.Key.u:
            y--;
            break;

        case Gdk.Key.Down:
        case Gdk.Key.j:
            y++;
            break;

        case Gdk.Key.space:
            if (keyboard_cursor.is_set)
            {
                selected.is_set = false;

                if ((state & Gdk.ModifierType.CONTROL_MASK) != 0)
                {
                    toggle_mark (keyboard_cursor.x, keyboard_cursor.y);
                }
                else
                {
                    selected.position = {x, y};
                    selected.is_set = true;
                }
            }
            break;

        /* Unset the keyboard cursor. */
        case Gdk.Key.Escape:
            return false;

        /* Ignore other keyboard keys but don't unset the cursor. */
        default:
            if (keyboard_cursor.is_set)
                break;
            else
                return false;
        }

        if (x == keyboard_cursor.x && y == keyboard_cursor.y)
        {
            keyboard_cursor.is_set = true;
            mines[keyboard_cursor.x,keyboard_cursor.y].add_class ("cursor");
            return true;
        }

        if (!keyboard_cursor.is_set)
        {
            keyboard_cursor.is_set = true;
            mines[keyboard_cursor.x,keyboard_cursor.y].add_class ("cursor");
            return true;
        }

        keyboard_cursor.position = {(int) (x == -1 ? _minefield.width-1 : x%_minefield.width), (int) (y == -1 ? _minefield.height-1 : y%_minefield.height)};

        mines[keyboard_cursor.x,keyboard_cursor.y].add_class ("cursor");
        if (selected.is_set)
            selected.position = {keyboard_cursor.x, keyboard_cursor.y};

        return true;
    }

    private inline void on_key_released (Gtk.EventControllerKey _key_controller, uint keyval, uint keycode, Gdk.ModifierType state)
    {
        if (keyval != Gdk.Key.space)
            return;

        /* Check for end cases and paused game */
        if (minefield.exploded || minefield.is_complete || minefield.paused)
            return;

        /* Check that the user isn't currently using the mouse */
        if (!selected.is_set || !keyboard_cursor.is_set)
            return;

        if (minefield.is_cleared (selected.x, selected.y))
            minefield.multi_release (selected.x, selected.y);
        else if (minefield.get_flag (selected.x, selected.y) != FlagType.FLAG)
            minefield.clear_mine (selected.x, selected.y);

        selected.is_set = false;
    }
}
