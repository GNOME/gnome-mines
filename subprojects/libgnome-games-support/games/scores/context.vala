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

/* Remove workaround once https://gitlab.gnome.org/GNOME/vala/-/issues/1429 is fixed. */
namespace Workaround
{
    [CCode (cheader_filename = "gtk/gtk.h", cname = "gtk_style_context_add_provider_for_display")]
    extern static void gtk_style_context_add_provider_for_display (
        Gdk.Display display, Gtk.StyleProvider provider, uint priority
    );
}

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
     * An App ID (e.g. ``org.gnome.Mines``).
     *
     */
    public string app_name { get; construct; }

    /**
     * Describes all of the categories (e.g. "Minefield", "Level").
     *
     */
    public string category_type { get; construct; }

    /**
     * The {@link Games.Scores.Style} that the context should use.
     *
     */
    public Style style { get; construct; }

    /**
     * The ID for the icon that will be used in the score dialog's empty screen (e.g. ``org.gnome.Quadrapassel``).
     *
     */
    public string icon_name { get; construct; }

    /**
     * The maximum size of the high score list in the score dialog (``-1`` for unlimited).
     *
     */
    public int max_high_scores { get; construct; }

    private Category? current_category = null;

    private HashTable<Category, GenericArray<Score>> scores_per_category =
        new HashTable<Category, GenericArray<Score>> (
            (a) => str_hash (a.key),
            (a, b) => str_equal (a.key, b.key)
        );

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

        /* Dialog styling */
        var display = Gdk.Display.get_default ();
        if (display != null)
        {
            var provider = new Gtk.CssProvider ();
            provider.load_from_string (DIALOG_STYLE);
            Workaround.gtk_style_context_add_provider_for_display (
                display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
         }
    }

    /**
     * Creates a new Context.
     *
     * ``app_name`` is your App ID (e.g. ``org.gnome.Mines``).
     *
     * ``category_type`` describes all of the categories (e.g. "Minefield", "Level").
     *
     * ``category_request`` is a function that takes a category key and produces the user-facing name for it.
     *
     * ``style changes`` the way {@link Games.Scores.Score}s are presented.
     *
     * ``icon_name`` is the ID for your app's icon (e.g. ``org.gnome.Quadrapassel``).
     *
     * ``max_high_scores`` is the maximum size of the high score list in the score dialog (``-1`` for unlimited).
     *
     */
    public Context (string app_name,
                    string category_type,
                    CategoryRequestFunc category_request,
                    Style style,
                    string? icon_name = null,
                    int max_high_scores = 10)
    {
        Object (app_name: app_name,
                category_type: category_type,
                style: style,
                icon_name: icon_name ?? app_name,
                max_high_scores: max_high_scores <= -1 ? int.MAX : max_high_scores);

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

    public Category[] get_categories ()
    {
        var categories = scores_per_category.get_keys ();
        categories.sort ((a, b) => {
            string key_1 = a.name.collate_key_for_filename ();
            string key_2 = b.name.collate_key_for_filename ();
            return strcmp (key_1, key_2);
        });
        var cat_array = new Category[0];
        foreach (var category in categories)
        {
            cat_array += category;
        }
        return cat_array;
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
    public Score[] get_high_scores (Category category, int n = -1)
    {
        var result = new Score[0];
        if (!scores_per_category.contains (category))
            return result;

        unowned var scores = scores_per_category[category];

        if (style == Style.POINTS_GREATER_IS_BETTER || style == Style.TIME_GREATER_IS_BETTER)
            scores_per_category[category].sort (Score.score_greater_sorter);
        else
            scores_per_category[category].sort (Score.score_less_sorter);

        if (n <= -1)
            n = max_high_scores;

        for (int i = 0; i < n && i < scores.length; i++) {
            var score = scores[i];
            score.rank = i + 1;
            result += score;
        }

        return result;
    }

    private bool is_high_score (long score_value, Category category)
    {
        var best_scores = get_high_scores (category);

        /* The given category doesn't yet exist and thus this score would be the first score and hence a high score. */
        if (best_scores == null)
            return true;

        if (best_scores.length < max_high_scores)
            return true;

        var lowest = best_scores[max_high_scores - 1].score;

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
        var line = @"$(score.score)$(score.get_internal_extra_info ()) $(score.time) $(score.user)\n";

        yield stream.write_all_async (line.data, Priority.DEFAULT, cancellable, null);
    }

    /**
     * Returns true if a dialog was launched on attaining high score.
     *
     */
    public async bool add_score (long score, Category category, Gtk.Window? game_window, Cancellable? cancellable) throws Error
    {
        var the_score = new Score (score);

        /* Check if category exists in the HashTable. Insert one if not. */
        if (!scores_per_category.contains (category))
            scores_per_category[category] = new GenericArray<Score> ();

        scores_per_category[category].add (the_score);
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
     * Adds extra info to the score, and optionally, some buttons to the bottom of the dialog that aid the flow of a game.
     *
     * ``new_game_func`` is called when the user presses the 'New Game' button on the dialog
     *
     * ``quit_app_func`` is called when the user presses the 'Quit' button on the dialog
     *
     */
    public async bool add_score_full (long score_value,
                                      Category category,
                                      string? extra_info,
                                      Gtk.Window? game_window,
                                      NewGameFunc? new_game_func,
                                      QuitAppFunc? quit_app_func,
                                      Cancellable? cancellable) throws Error
    {
        Score score = new Score (score_value);
        score.extra_info = extra_info;
        /* Check if category exists in the HashTable. Insert one if not. */
        if (!scores_per_category.contains (category))
            scores_per_category[category] = new GenericArray<Score> ();

        scores_per_category[category].add (score);
        current_category = category;

        var high_score_added = is_high_score (score.score, category);
        if (high_score_added && game_window != null)
        {
            var dialog = new Dialog (this, category_type, style, score, current_category, icon_name);
            dialog.closed.connect (() => add_score_full.callback ());
            dialog.present (game_window);
            if (new_game_func != null && quit_app_func != null)
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
        var scores_of_single_category = new GenericArray<Score> ();
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

            long score_value = 0;

            /* '#' adds extra info */
            var score_tokens = tokens[0].split ("#", 2);
            score_value = long.parse (score_tokens[0]);
            var time = int64.parse (tokens[1]);

            if (score_value == 0 && score_tokens[0] != "0" ||
                time == 0 && tokens[1] != "0")
            {
                warning ("Failed to read malformed score %s in %s.", line, filename);
                continue;
            }

            if (tokens.length == 3)
                user = tokens[2];
            else
                debug ("Assuming current username for old score %s in %s.", line, filename);

            var score = new Score (score_value, time, user);
            if (score_tokens.length == 2)
                score._extra_info = score_tokens[1];

            scores_of_single_category.add (score);
        }

        scores_per_category[category] = scores_of_single_category;
    }

    private void load_scores_from_files () throws Error
        requires (!scores_loaded)
    {
        scores_loaded = true;

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
     * ``selected_category`` is the score category to select by default (optional)
     *
     */
    public void present_dialog (Gtk.Window game_window, Category? selected_category = null)
    {
        if (selected_category == null || !scores_per_category.contains (selected_category))
            selected_category = current_category;

        var dialog = new Dialog (this, category_type, style, null, selected_category, icon_name);
        dialog.closed.connect (() => dialog_closed ());
        dialog.present (game_window);
    }

    /**
     * Returns true if this contains {@link Games.Scores.Score}s.
     *
     */
    public bool has_scores ()
    {
        foreach (var scores in scores_per_category.get_values ())
        {
            if (scores.length > 0)
                return true;
        }
        return false;
    }
}

} /* namespace Scores */
} /* namespace Games */
