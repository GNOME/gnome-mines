/*
 * Copyright (C) 2011-2012 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public enum FlagType
{
    NONE,
    FLAG,
    MAYBE
}

private class Location
{
    /* true if contains a mine */
    public bool has_mine = false;
    
    /* true if cleared */
    public bool cleared = false;

    /* Flag */
    public FlagType flag = FlagType.NONE;
}

/* Table of offsets to adjacent squares */
private struct Neighbour
{
    public int x;
    public int y;
}
private static const Neighbour neighbour_map[] =
{
    {-1, 1},
    {0, 1},
    {1, 1},
    {1, 0},
    {1, -1},
    {0, -1},
    {-1, -1},
    {-1, 0}
};

public class Minefield
{
    /* Size of map */
    public uint width = 0;
    public uint height = 0;
    
    /* Number of mines in map */
    public uint n_mines = 0;

    /* State of each location */
    private Location[,] locations;

    /* true if have hit a mine */
    public bool exploded = false;

    /* true if have placed the mines onto the map */
    private bool placed_mines = false;

    /* keep track of flags and cleared squares */
    private uint _n_cleared = 0;
    private uint _n_flags = 0;

    public uint n_cleared
    {
        get { return _n_cleared; }
        set { _n_cleared = value; }
    }

    public bool is_complete
    {
        get { return n_cleared == width * height - n_mines; }
    }

    public uint n_flags
    {
        get { return _n_flags; }
        set { _n_flags = value; }
    }

    /* Game timer */
    private double clock_elapsed;
    private Timer? clock;
    private uint clock_timeout;

    /* Time penalty for a hint increases the more you use it */
    private static const uint HINT_TIME_PENALTY_MAX = 90;
    private static const uint HINT_TIME_PENALTY_INCREASE = 10;
    private uint hint_time_penalty_seconds = 10;

    public double elapsed
    {
        get
        {
            if (clock == null)
                return 0.0;
            return clock_elapsed + clock.elapsed ();
        }
    }

    private bool _paused = false;
    public bool paused
    {
        set
        {
            if (is_complete || exploded)
                return;

            if (clock != null)
            {
                if (value && !_paused)
                    stop_clock ();
                else if (!value && _paused)
                    continue_clock ();
            }

            _paused = value;
            paused_changed ();
        }
        get { return _paused; }
    }

    public signal void clock_started ();
    public signal void paused_changed ();
    public signal void tick ();

    public signal void redraw_sector (uint x, uint y);

    public signal void marks_changed ();
    public signal void explode ();
    public signal void cleared ();

    public Minefield (uint width, uint height, uint n_mines)
    {
        locations = new Location[width, height];
        for (var x = 0; x < width; x++)
            for (var y = 0; y < height; y++)
                locations[x, y] = new Location ();
        this.width = width;
        this.height = height;
        this.n_mines = n_mines;
    }

    public bool is_clock_started ()
    {
        return elapsed > 0;
    }
   
    public bool has_mine (uint x, uint y)
    {
        return locations[x, y].has_mine;
    }

    public bool is_cleared (uint x, uint y)
    {
        return locations[x, y].cleared;
    }

    public bool is_location (int x, int y)
    {
        return x >= 0 && y >= 0 && x < width && y < height;
    }

    public void clear_mine (uint x, uint y)
    {
        start_clock ();

        /* Place mines on first attempt to clear */
        if (!placed_mines)
        {
            place_mines (x, y);
            placed_mines = true;
        }

        if (locations[x, y].cleared || locations[x, y].flag == FlagType.FLAG)
            return;

        clear_mines_recursive (x, y);

        /* Failed if this contained a mine */
        if (locations[x, y].has_mine)
        {
            if (!exploded)
            {
                exploded = true;
                stop_clock ();
                explode ();
            }
            return;
        }

        /* Mark unmarked mines when won */
        if (is_complete)
        {
            stop_clock ();
            for (var tx = 0; tx < width; tx++)
                for (var ty = 0; ty < height; ty++)
                    if (has_mine (tx, ty))
                        set_flag (tx, ty, FlagType.FLAG);
            cleared ();
        }
    }

    private void clear_mines_recursive (uint x, uint y)
    {
        /* Ignore if already cleared */
        if (locations[x, y].cleared)
            return;

        locations[x, y].cleared = true;
        n_cleared++;
        if (locations[x, y].flag == FlagType.FLAG)
            n_flags--;
        locations[x, y].flag = FlagType.NONE;
        redraw_sector (x, y);
        marks_changed ();

        /* Automatically clear locations if no adjacent mines */
        if (!locations[x, y].has_mine && get_n_adjacent_mines (x, y) == 0)
        {
            foreach (var neighbour in neighbour_map)
            {
                var nx = (int) x + neighbour.x;
                var ny = (int) y + neighbour.y;
                if (is_location (nx, ny))
                    clear_mines_recursive (nx, ny);
            }
        }
    }

    public void set_flag (uint x, uint y, FlagType flag)
    {
        if (locations[x, y].cleared || locations[x, y].flag == flag)
            return;

        if (flag == FlagType.FLAG)
            n_flags++;
        else if (locations[x, y].flag == FlagType.FLAG)
            n_flags--;

        locations[x, y].flag = flag;
        redraw_sector (x, y);

        /* Update warnings */
        /* FIXME: Doesn't check if have changed, just if might have changed */
        foreach (var neighbour in neighbour_map)
        {
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
            if (is_location (nx, ny) && is_cleared (nx, ny))
                redraw_sector (nx, ny);
        }

        marks_changed ();
    }
    
    public FlagType get_flag (uint x, uint y)
    {
        return locations[x, y].flag;
    }

    public void hint ()
    {
        /* We search for three cases:
         *
         * Case 1: we look for squares adjacent to both a mine and a revealed
         * square since these are most likely to help the player and resolve
         * ambiguous situations.
         *
         * Case 2: we look for squares that are adjacent to a mine
         * (this will only occur in the rare case that a square is completely
         * encircled by mines, but at that point this case is probably
         * useful).
         *
         * Case 3: we look for any unrevealed square without a mine (as a
         * consequence of the previous cases this won't be adjacent to a
         * mine).
         */

        List<uint> case1list = null;
        List<uint> case2list = null;
        List<uint> case3list = null;

        for (var mx = 0; mx < width; mx++)
        {
            for (var my = 0; my < height; my++)
            {
                var m = locations[mx, my];
                if (!m.has_mine && !m.cleared)
                {
                    case3list.append (mx * width + my);
                    if (m.flag != FlagType.FLAG && get_n_adjacent_mines (mx, my) > 0)
                    {
                        case2list.append (mx * width + my);
                        foreach (var neighbour in neighbour_map)
                        {
                            if (!is_location (mx + neighbour.x, my + neighbour.y))
                                 continue;
                            if (locations[mx + neighbour.x, my + neighbour.y].cleared)
                            {
                                case1list.append (mx * width + my);
                                break;
                            }
                        }
                    }
                }
            }
        }

        uint hint_location = 0;
        if (case1list.length () > 0)
            hint_location = case1list.nth_data (Random.int_range (0, (int32) case1list.length ()));
        else if (case2list.length () > 0)
            hint_location = case2list.nth_data (Random.int_range (0, (int32) case2list.length ()));
        else if (case3list.length () > 0)
            hint_location = case3list.nth_data (Random.int_range (0, (int32) case3list.length ()));

        /* Makes sure that the program knows about the successful
         * hint before a possible win. */
        var x = hint_location / width;
        var y = hint_location % width;

        if (locations[x, y].flag == FlagType.FLAG)
            locations[x, y].flag = FlagType.NONE;

        /* There is a ten second penalty for accepting a hint_action. */
        clear_mine (x, y);
        clock_elapsed += hint_time_penalty_seconds;
        if (hint_time_penalty_seconds < HINT_TIME_PENALTY_MAX)
            hint_time_penalty_seconds += HINT_TIME_PENALTY_INCREASE;
        tick ();
    }

    public uint get_n_adjacent_mines (uint x, uint y)
    {
        uint n = 0;
        foreach (var neighbour in neighbour_map)
        {
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
            if (is_location (nx, ny) && has_mine (nx, ny))
                n++;
        }
        return n;
    }

    public bool has_flag_warning (uint x, uint y)
    {
        if (!is_cleared (x, y))
            return false;

        uint n_mines = 0, n_flags = 0;
        foreach (var neighbour in neighbour_map)
        {
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
            if (!is_location (nx, ny))
                continue;
            if (has_mine (nx, ny))
                n_mines++;
            if (get_flag (nx, ny) == FlagType.FLAG)
                n_flags++;
        }

        return n_flags > n_mines;
    }

    /* Randomly set the mines, but avoid the current and adjacent locations */
    private void place_mines (uint x, uint y)
    {
        for (var n = 0; n < n_mines;)
        {
            var rx = Random.int_range (0, (int32) width);
            var ry = Random.int_range (0, (int32) height);
            
            if (rx == x && ry == y)
                continue;

            if (!locations[rx, ry].has_mine)
            {
                var adj_found = false;

                foreach (var neighbour in neighbour_map)
                {
                    if (rx == x + neighbour.x && ry == y + neighbour.y)
                    {
                        adj_found = true;
                        break;
                    }
                }

                if (!adj_found)
                {
                    locations[rx, ry].has_mine = true;
                    n++;
                }
            }
        }
    }

    private void start_clock ()
    {
        if (clock == null)
            clock = new Timer ();
        clock_started ();
        timeout_cb ();
    }

    private void stop_clock ()
    {
        if (clock == null)
            return;
        if (clock_timeout != 0)
            Source.remove (clock_timeout);
        clock_timeout = 0;
        clock.stop ();
        tick ();
    }

    private void continue_clock ()
    {
        if (clock == null)
            clock = new Timer ();
        else
            clock.continue ();
        timeout_cb ();
    }

    private bool timeout_cb ()
    {
        /* Notify on the next tick */
        var elapsed = clock.elapsed ();
        var next = (int) (elapsed + 1.0);
        var wait = next - elapsed;
        clock_timeout = Timeout.add ((int) (wait * 1000), timeout_cb);

        tick ();

        return false;
    }
}
