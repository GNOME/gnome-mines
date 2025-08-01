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

/* Imports scores from an old scores directory, where each category of scores is
 * saved in a separate file. This is the format used by old C games that were
 * never converted to Vala before switching to libgnome-games-support. This class
 * should probably be used by Five or More, Nibbles, Robots, Tali, and nothing
 * else.
 */
[Version (deprecated=true, deprecated_since="3.0")]
public class DirectoryImporter : Importer
{
    /* A function provided by the game that converts the old category key to a
     * new key. If the keys have not been changed, this function should return
     * the same string. If the key is invalid, it should return null, as this
     * function will be called once for each file in the game's local data
     * directory, and some of those files might not be valid categories.
     */
    [Version (deprecated=true, deprecated_since="3.0")]
    public delegate string? CategoryConvertFunc (string old_key);
    private CategoryConvertFunc? category_convert;

    construct
    {
        /* Unset this manually because it holds a circular ref the Importer. */
        this.finished.connect (() => this.category_convert = null);
    }

    [Version (deprecated=true, deprecated_since="3.0")]
    public DirectoryImporter ()
    {
        /* Default converter for games that don't require category migration. */
        set_category_convert_func ((old_key) => { return old_key; });
    }

    [Version (deprecated=true, deprecated_since="3.0")]
    public DirectoryImporter.with_convert_func (CategoryConvertFunc category_convert)
    {
        set_category_convert_func (category_convert);
    }

    [Version (deprecated=true, deprecated_since="3.0")]
    public void set_category_convert_func (CategoryConvertFunc category_convert)
    {
        this.category_convert = (old_key) => { return category_convert (old_key); };
    }

    /* This scores format is mostly-compatible with the current format, the only
     * differences are (a) the scores file nowadays has a column for the player
     * name, (b) scores nowadays are kept under ~/.local/share/APPNAME/scores
     * whereas they used to be saved one level up, and (c) some category names
     * have changed. All we have to do here is copy the files from the parent
     * directory to the subdirectory, and rename them according to the new
     * category names. Context.load_scores_from_file handles the missing player
     * name column by assuming it matches the current UNIX account if missing.
     * Notice that we are importing only home directory scores, not any scores
     * from /var/games, since it's been several years since scores were removed
     * from there and most players will have lost them by now anyway.
     */
    protected override void importOldScores (Context context, File new_scores_dir) throws Error
    {
        var original_scores_dir = new_scores_dir.get_parent ();
        assert (original_scores_dir != null);

        var enumerator = original_scores_dir.enumerate_children (FileAttribute.STANDARD_NAME, 0);
        FileInfo file_info;
        while ((file_info = enumerator.next_file ()) != null)
        {
            /* We just created this.... */
            if (file_info.get_name () == "scores")
                continue;

            var new_key = category_convert (file_info.get_name ());
            if (new_key == null)
                continue;

            var new_file = new_scores_dir.get_child (new_key);
            var original_file = original_scores_dir.resolve_relative_path (file_info.get_name ());
            debug ("Moving scores from %s to %s", original_file.get_path (), new_file.get_path ());
            original_file.copy (new_file, FileCopyFlags.NONE);
            original_file.@delete ();
        }
    }
}

} /* namespace Scores */
} /* namespace Games */
