/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright © 2016 Michael Catanzaro <mcatanzaro@gnome.org>
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

/* Imports scores from a Vala game's history file directory, where each category
 * of scores is saved together in the same file. This is the format used by
 * games that were converted to Vala before switching to libgnome-games-support. This
 * class should probably be used by Klotski, Mines, Swell Foop, Mahjongg,
 * Tetravex, Quadrapassel, and nothing else.
 */
[Version (deprecated=true, deprecated_since="3.0")]
public class HistoryFileImporter : Importer
{
    /* A function provided by the game that converts a line in its history file
     * to a Score and Category we can use.
     */
    [Version (deprecated=true, deprecated_since="3.0")]
    public delegate void HistoryConvertFunc (string line, out Score score, out Category category);
    private HistoryConvertFunc? history_convert;

    construct
    {
        /* Unset this manually because it holds a circular ref the Importer. */
        this.finished.connect (() => this.history_convert = null);
    }

    [Version (deprecated=true, deprecated_since="3.0")]
    public HistoryFileImporter (HistoryConvertFunc history_convert)
    {
        set_history_convert_func (history_convert);
    }

    [Version (deprecated=true, deprecated_since="3.0")]
    public void set_history_convert_func (HistoryConvertFunc history_convert)
    {
        this.history_convert = (line, out score, out category) => {
            history_convert (line, out score, out category);
        };
    }

    [Version (deprecated=true, deprecated_since="3.0")]
    public static int64 parse_date (string date)
    {
        var date_time = new DateTime.from_iso8601 (date, null);
        if (date_time == null)
            warning ("Failed to parse date: %s", date);
        return date_time.to_unix ();
    }

    /* Each game uses a somewhat different format for its scores; one game might
     * use one column to store the category, while another might use two or
     * more. Pass the game one line of the history file at a time, and let the
     * game convert it to a Score and Category for us.
     */
    protected override void importOldScores (Context context, File new_scores_dir) throws GLib.Error
    {
        var history_filename = Path.build_filename (new_scores_dir.get_path (), "..", "history", null);
        var stream = FileStream.open (history_filename, "r");
        if (stream == null)
            return;

        debug ("Importing scores from %s", history_filename);

        string line;
        while ((line = stream.read_line ()) != null)
        {
            Score score;
            Category category;
            history_convert (line, out score, out category);
            if (score == null || category == null)
                warning ("Failed to import from %s score line %s", history_filename, line);
            add_score_sync (context, score, category);
        }

        var history_file = File.new_for_path (history_filename);
        history_file.@delete ();
    }

    private bool add_score_sync (Context context, Score score, Category category) throws Error
    {
        var main_context = new MainContext ();
        var main_loop = new MainLoop (main_context);
        var ret = false;
        Error error = null;

        main_context.push_thread_default ();
        context.add_score_internal.begin (score, category, null, (object, result) => {
            try
            {
                ret = context.add_score_internal.end (result);
            }
            catch (Error e)
            {
                error = e;
            }
            main_loop.quit ();
        });
        main_loop.run ();
        main_context.pop_thread_default ();

        if (error != null)
            throw error;
        return ret;
    }
}

} /* namespace Scores */
} /* namespace Games */
