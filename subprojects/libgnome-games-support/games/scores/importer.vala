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

/* Time for a history lesson. Once upon a time, scores were stored under
 * /var/games in a format basically the same as what we use now, split into
 * different files based on category. Games were installed setgid for the games
 * group, allowing scores to be shared between users (fun in a computer lab or
 * shared machine) while preventing cheating, since editing the scores file
 * would require some privilege escalation exploit.
 *
 * When Robert started rewriting games in Vala, he changed the scores format so
 * that all scores for a game would be saved in one file, in the home directory.
 * Placing the file in the home directory has an important advantage in that you
 * do not lose your scores if you copy your home directory to another computer.
 * Of course, this had the one-time cost that scores were lost upon upgrading
 * to the new Vala version of the game, as there was no score importer. It also
 * makes importing a bit tricky, because the columns in the scores file are
 * different for each game.
 *
 * Then, for GNOME 3.12, I (Michael) changed all the remaining C games to store
 * scores in the home directory, without changing the format except for removing
 * the player name column, since it didn't seem relevant if all scores were in
 * the home directory. Again, all users' scores were lost in this transition.
 * Currently, scores use this same format, except the player name column is back
 * because it turns out people share user accounts and want to record scores
 * separately.
 *
 * These importers exist so that we don't delete everyone's scores a second
 * time.
 *
 * Some users have complained that scores are now saved in the home directory.
 * Using /var/games was a clever setup and it's a bit of a shame to see it go;
 * bug #749682 exists to restore that old behavior. It has been suggested that
 * we could hardlink scores files from the home directory to /var/games to get
 * the best of both worlds. I don't see why not, except some distro folks really
 * don't like using the setgid bit. Another possibility would be to make this
 * some configurable option. Few enough people have been complaining that I
 * don't plan to spend more time on this, though.
 */

/* Note that importers must operate synchronously. This is fine because the
 * importer is only used before scores are loaded, and we ensure scores are
 * loaded before showing the main window.
 */

[Version (deprecated=true, deprecated_since="3.0")]
public abstract class Importer : Object
{
    [Version (deprecated=true, deprecated_since="3.0")]
    protected abstract void importOldScores (Context context, File new_scores_dir) throws Error;

    /* This would be much nicer as an abstract function rather than a signal;
     * however, adding a new abstract function would enlarge the class struct,
     * breaking ABI.
     */
    [Version (since="3.0", deprecated=true, deprecated_since="3.0")]
    public signal void finished ();

    internal void run (Context context, string new_scores_dir)
    {
        var new_dir = File.new_for_path (new_scores_dir);
        if (!new_dir.query_exists ())
        {
            try
            {
                new_dir.make_directory_with_parents ();
                importOldScores (context, new_dir);
            }
            catch (Error e)
            {
                warning ("Failed to import scores: %s", e.message);
            }
        }

        finished ();
    }
}

} /* namespace Scores */
} /* namespace Games */
