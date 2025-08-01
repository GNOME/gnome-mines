/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright © 2015 Michael Catanzaro <mcatanzaro@gnome.org>
 *
 * This file is part of libgnome-games-support.
 *
 * libgnome-games-support is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * libgnome-games-support is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with libgnome-games-support.  If not, see <http://www.gnu.org/licenses/>.
 */

// This is a fairly literal translation of the LGPLv2+
// original by Callum McKenzie, itself based on GtkFrame and GtkAspectFrame.

namespace Games {

/**
 * A container that guarantees that the internal allocated space is a fixed
 * multiple of an integer.
 *
 */
public class GridFrame : Gtk.Widget
{

    private int _xpadding = 0;
    /**
     * The horizontal padding of the GridFrame.
     *
     */
    public int xpadding
    {
        get { return _xpadding; }

        set
        {
            if (value >= 0)
            {
                _xpadding = value;
                queue_resize ();
            }
        }
    }

    private int _ypadding = 0;
    /**
     * The vertical padding of the GridFrame.
     *
     */
    public int ypadding
    {
        get { return _ypadding; }

        set
        {
            if (value >= 0)
            {
                _ypadding = value;
                queue_resize ();
            }
        }
    }

    private int _xmult = 1;
    /**
     * The width of the GridFrame.
     *
     */
    public int width
    {
        get { return _xmult; }

        set
        {
            if (value > 0)
            {
                _xmult = value;
                queue_resize ();
            }
        }
    }

    private int _ymult = 1;
    /**
     * The height of the GridFrame.
     *
     */
    public int height
    {
        get { return _ymult; }

        set
        {
            if (value > 0)
            {
                _ymult = value;
                queue_resize ();
            }
        }
    }

    private float _xalign = 0.5f;
    /**
     * The horizontal alignment of the GridFrame.
     * ranges from zero to one, .5 makes the GridFrame centered.
     *
     */
    public float xalign
    {
        get { return _xalign; }

        set
        {
            _xalign = value.clamp (0.0f, 1.0f);
            queue_resize ();
        }
    }

    private float _yalign = 0.5f;
    /**
     * The vertical alignment of the GridFrame.
     * ranges from zero to one, .5 makes the GridFrame centered.
     *
     */
    public float yalign
    {
        get { return _yalign; }

        set
        {
            _yalign = value.clamp (0.0f, 1.0f);
            queue_resize ();
        }
    }

    private Gtk.Widget _child = null;
    /**
     * The child of the GridFrame.
     *
     */
    public Gtk.Widget child {
        get { return _child; }

        set
        {
            if (_child == value)
                return;
            if (_child != null)
                _child.unparent ();
            _child = value;
            if (_child != null)
                _child.set_parent (this);
            queue_resize ();
        }
    }

    private Gtk.Allocation old_allocation;

    /**
     * Creates a new GridFrame.
     *
     */
    public GridFrame (int width, int height)
    {
        Object (width: width, height: height);
    }

    /**
     * Disposes of the GridFrame and removes it's child from itself.
     *
     */
    protected override void dispose () {
        child.unparent ();
        child = null;

        base.dispose ();
    }

    /**
     * Sets the width and height of the GridFrame.
     *
     */
    public new void @set (int width, int height)
    {
        this.width = width;
        this.height = height;
    }

    /**
     * Sets the horizontal and vertical (x and y) padding of the GridFrame.
     *
     */
    public void set_padding (int xpadding, int ypadding)
    {
        this.xpadding = xpadding;
        this.ypadding = ypadding;
    }

    /**
     * Sets the horizontal and vertical (x and y) alignment of the GridFrame.
     *
     * ``xalign`` and ``yalign`` range from zero to one, if both are set to .5 the GridFrame will be centered.
     *
     */
    public void set_alignment (float xalign, float yalign)
    {
        this.xalign = xalign;
        this.yalign = yalign;
    }

    /**
     * {@link Gtk.Widget.size_allocate}
     *
     */
    public override void size_allocate (int width, int height, int baseline)
    {
        base.size_allocate (width, height, baseline);

        int xsize = int.max (1, (width - _xpadding) / _xmult);
        int ysize = int.max (1, (height - _ypadding) / _ymult);
        int size = int.min (xsize, ysize);

        Gtk.Allocation child_allocation = { 0, 0, 0, 0 };
        child_allocation.width = size * _xmult + _xpadding;
        child_allocation.height = size * _ymult + _ypadding;
        child_allocation.x = (int) ((width - child_allocation.width) * _xalign);
        child_allocation.y = (int) ((height - child_allocation.height) * _yalign);

        if (child != null && child.get_visible ())
            child.allocate_size (child_allocation, -1);

        old_allocation = child_allocation;
    }
}

}  // namespace Games
