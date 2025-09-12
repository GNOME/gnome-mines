/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright © 2014 Nikhar Agrawal
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

namespace Games {
namespace Scores {

/**
 * The style that a {@link Games.Scores.Score} uses.
 *
 * This tells the score dialog if it should display the scores as a time or as points.
 *
 * It also tells the score dialog if a larger or smaller score should get a higher ranking.
 *
 */
public enum Style
{
    POINTS_GREATER_IS_BETTER,
    POINTS_LESS_IS_BETTER,
    TIME_GREATER_IS_BETTER,
    TIME_LESS_IS_BETTER
}

/**
 * An object that holds information for using {@link Games.Scores.Score}s.
 *
 */
public class Context : Object
{
    /**
     * An App ID (eg. ``org.gnome.Mines``).
     *
     */
    public string app_name { get; construct; }

    /**
     * Describes all of the categories.
     * Make sure to put a colon at the end (eg. "Minefield:", "Difficulty Level:").
     *
     */
    public string category_type { get; construct; }

    /**
     * The window that the game will be inside of, this is the window the score dialog will be presented upon.
     *
     */
    public Gtk.Window? game_window { get; construct; }

    /**
     * The {@link Games.Scores.Style} that the context should use.
     *
     */
    public Style style { get; construct; }

    /**
     * The ID for the icon that will be used in the score dialog's empty screen (eg. ``org.gnome.Quadrapassel``).
     *
     */
    public string icon_name { get; construct; }

    private Category? current_category = null;

    private static Gee.HashDataFunc<Category?> category_hash = (a) => {
        return str_hash (a.key);
    };
    private static Gee.EqualDataFunc<Category?> category_equal = (a,b) => {
        return str_equal (a.key, b.key);
    };
    private Gee.HashMap<Category?, Gee.List<Score>> scores_per_category =
        new Gee.HashMap<Category?, Gee.List<Score>> ((owned) category_hash, (owned) category_equal);

    private string user_score_dir;
    private bool scores_loaded = false;

    /**
     * A function provided by the game that converts the category key to a category.
     *
     * Why do we have this, instead of expecting games to pass in a list
     * of categories? Because some games need to create categories on the
     * fly, like Mines, which allows for custom board sizes. These games do not
     * know in advance which categories may be in use.
     *
     */
    public delegate Category? CategoryRequestFunc (string category_key);
    private CategoryRequestFunc? category_request = null;

    /**
     * Emitted when the score dialog is closed.
     *
     */
    public signal void dialog_closed ();

    class construct
    {
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
    }

    /**
     * Creates a new Context.
     *
     * ``app_name`` is your App ID (eg. ``org.gnome.Mines``)
     *
     * ``category_type`` describes all of the categories, make sure to put a colon at the end (eg. "Minefield:", "Difficulty Level:").
     *
     * ``game_window`` is the window that the game will be inside of, this is the window the score dialog will be presented upon.
     *
     * ``category_request`` is a function that takes a category key and produces the user-facing name for it.
     *
     * ``style changes`` the way {@link Games.Scores.Score}s are presented.
     *
     * ``icon_name`` is the ID for your app's icon (eg. ``org.gnome.Quadrapassel``).
     *
     */
    public Context (string app_name,
                    string category_type,
                    Gtk.Window? game_window,
                    CategoryRequestFunc category_request,
                    Style style,
                    string? icon_name = null)
    {
        Object (app_name: app_name,
                category_type: category_type,
                game_window: game_window,
                style: style,
                icon_name: icon_name ?? app_name);

        /* Note: the following functionality can be performed manually by
         * calling Context.load_scores, to ensure Context is usable even if
         * constructed with g_object_new.
         */
        this.category_request = (key) => { return category_request (key); };
        try
        {
            load_scores_from_files ();
        }
        catch (Error e)
        {
            warning ("Failed to load scores: %s", e.message);
        }

        /* Unset this manually because it holds a circular ref on Context. */
        this.category_request = null;
    }

    public override void constructed ()
    {
        user_score_dir = Path.build_filename (Environment.get_user_data_dir (), app_name, "scores", null);
    }

    internal List<Category?> get_categories ()
    {
        var categories = new List<Category?> ();
        var iterator = scores_per_category.map_iterator ();

        while (iterator.next ())
        {
            categories.append (iterator.get_key ());
        }

        return categories;
    }

    /* Primarily used to change name of player and save the changed score to file */
    internal void update_score_name (Score old_score, Category category, string new_name)
    {
        foreach (var score in scores_per_category[category])
        {
            if (Score.equals (score, old_score))
            {
                score.user = new_name;
                return;
            }
        }
        assert_not_reached ();
    }

    /**
     * Get the best n scores from the given category, sorted.
     *
     */
    public Gee.List<Score> get_high_scores (Category category, int n = 10)
    {
        var result = new Gee.ArrayList<Score> ();
        if (!scores_per_category.has_key (category))
            return result;

        if (style == Style.POINTS_GREATER_IS_BETTER || style == Style.TIME_GREATER_IS_BETTER)
        {
            scores_per_category[category].sort ((a,b) => {
                return (int) (b.score > a.score) - (int) (a.score > b.score);
            });
        }
        else
        {
            scores_per_category[category].sort ((a,b) => {
                return (int) (b.score < a.score) - (int) (a.score < b.score);
            });
        }

        for (int i = 0; i < n && i < scores_per_category[category].size; i++)
            result.add (scores_per_category[category][i]);
        return result;
    }

    private bool is_high_score (long score_value, Category category)
    {
        var best_scores = get_high_scores (category);

        /* The given category doesn't yet exist and thus this score would be the first score and hence a high score. */
        if (best_scores == null)
            return true;

        if (best_scores.size < 10)
            return true;

        var lowest = best_scores.@get (9).score;

        if (style == Style.POINTS_LESS_IS_BETTER || style == Style.TIME_LESS_IS_BETTER)
            return score_value < lowest;

        return score_value > lowest;
    }

    private async void save_score_to_file (Score score, Category category, Cancellable? cancellable) throws Error
    {
        if (DirUtils.create_with_parents (user_score_dir, 0766) == -1)
        {
            throw new FileError.FAILED ("Failed to create %s: %s", user_score_dir, strerror (errno));
        }

        var file = File.new_for_path (Path.build_filename (user_score_dir, category.key));
        var stream = file.append_to (FileCreateFlags.NONE);
        var line = @"$(score.score) $(score.time) $(score.user)\n";

        yield stream.write_all_async (line.data, Priority.DEFAULT, cancellable, null);
    }

    /**
     * Returns true if a dialog was launched on attaining high score.
     *
     */
    public async bool add_score (long score, Category category, Cancellable? cancellable) throws Error
    {
        var the_score = new Score (score);

        /* Check if category exists in the HashTable. Insert one if not. */
        if (!scores_per_category.has_key (category))
            scores_per_category.set (category, new Gee.ArrayList<Score> ());

        if (scores_per_category[category].add (the_score))
            current_category = category;

        var high_score_added = is_high_score (the_score.score, category);
        if (high_score_added && game_window != null)
        {
            var dialog = new Dialog (this, category_type, style, the_score, current_category, icon_name);
            dialog.closed.connect (() => add_score.callback ());
            dialog.present (game_window);
            yield;
        }

        yield save_score_to_file (the_score, category, cancellable);
        return high_score_added;
    }

    public delegate void NewGameFunc ();
    public delegate void QuitAppFunc ();

    /**
     * Adds some buttons to the bottom of the dialog that aid the flow of a game that chooses to use it.
     *
     * ``new_game_func`` is called when the user presses the 'New Game' button on the dialog
     *
     * ``quit_app_func`` is called when the user presses the 'Quit' button on the dialog
     *
     */
    public async bool add_score_full (long score_value, Category category, NewGameFunc new_game_func, QuitAppFunc quit_app_func, Cancellable? cancellable) throws Error
    {
        Score score = new Score (score_value);
        /* Check if category exists in the HashTable. Insert one if not. */
        if (!scores_per_category.has_key (category))
            scores_per_category.set (category, new Gee.ArrayList<Score> ());

        if (scores_per_category[category].add (score))
            current_category = category;

        var high_score_added = is_high_score (score.score, category);
        if (high_score_added)
        {
            var dialog = new Dialog (this, category_type, style, score, current_category, icon_name);
            dialog.closed.connect (() => add_score_full.callback ());
            dialog.present (game_window);
            dialog.add_bottom_buttons (new_game_func, quit_app_func);
            yield;
        }

        yield save_score_to_file (score, category, cancellable);
        return high_score_added;
    }

    private void load_scores_from_file (FileInfo file_info) throws Error
    {
        var category_key = file_info.get_name ();
        var category = category_request (category_key);
        if (category == null)
            return;

        var filename = Path.build_filename (user_score_dir, category_key);
        var scores_of_single_category = new Gee.ArrayList<Score> ();
        var stream = FileStream.open (filename, "r");
        string line;
        while ((line = stream.read_line ()) != null)
        {
            var tokens = line.split (" ", 3);
            string? user = null;

            if (tokens.length < 2)
            {
                warning ("Failed to read malformed score %s in %s.", line, filename);
                continue;
            }

            var score_value = long.parse (tokens[0]);
            var time = int64.parse (tokens[1]);

            if (score_value == 0 && tokens[0] != "0" ||
                time == 0 && tokens[1] != "0")
            {
                warning ("Failed to read malformed score %s in %s.", line, filename);
                continue;
            }

            if (tokens.length == 3)
                user = tokens[2];
            else
                debug ("Assuming current username for old score %s in %s.", line, filename);

            scores_of_single_category.add (new Score (score_value, time, user));
        }

        scores_per_category.set (category, scores_of_single_category);
    }

    private void load_scores_from_files () throws Error
        requires (!scores_loaded)
    {
        scores_loaded = true;

        if (game_window != null && game_window.visible)
        {
            error ("The application window associated with the GamesScoresContext " +
                   "was set visible before loading scores. The Context performs " +
                   "synchronous I/O in the default main context to load scores, so " +
                   "so you should do this before showing your main window.");
        }

        var directory = File.new_for_path (user_score_dir);
        if (!directory.query_exists ())
            return;

        var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);
        FileInfo file_info;
        while ((file_info = enumerator.next_file ()) != null)
        {
            load_scores_from_file (file_info);
        }
    }

    /**
     * Must be called *immediately* after construction, if constructed using
     * g_object_new.
     *
     */
    public void load_scores (CategoryRequestFunc category_request) throws Error
        requires (this.category_request == null)
    {
        this.category_request = (key) => { return category_request (key); };
        load_scores_from_files ();

        /* Unset this manually because it holds a circular ref on Context. */
        this.category_request = null;
    }

    /**
     * Presents the score dialog on top of ``game_window``.
     *
     */
    public void present_dialog ()
        requires (game_window != null)
    {
        var dialog = new Dialog (this, category_type, style, null, current_category, icon_name);
        dialog.closed.connect (() => dialog_closed ());
        dialog.present (game_window);
    }

    /**
     * Returns true if this contains {@link Games.Scores.Score}s.
     *
     */
    public bool has_scores ()
    {
        foreach (var scores in scores_per_category.values)
        {
            if (scores.size > 0)
                return true;
        }
        return false;
    }
}

} /* namespace Scores */
} /* namespace Games */
