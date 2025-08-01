/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright © 2014 Nikhar Agrawal
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
 * A category of {@link Games.Scores.Score}, usually the game mode (hard, easy, medium) that a score is from.
 *
 */
public class Category : Object
{
    private string _key;
    /**
     * A non-translated string that is not user facing and is used to identify the Category.
     *
     * Category ``key``s may contain only hyphens, underscores, and alphanumeric characters.
     *
     */
    public string key
    {
        get { return _key; }
        set
        {
            for (int i = 0; value[i] != '\0'; i++)
            {
                if (!value[i].isalnum () && value[i] != '-' && value[i] != '_')
                {
                    error ("Category keys may contain only hyphens, underscores, and alphanumeric characters.");
                }
            }
            _key = value;
        }
    }

    /**
     * A user-friendly name for the Category.
     * This should be marked for translation.
     *
     */
    public string name { get; set; }

    /**
     * Creates a new Category.
     *
     */
    public Category (string key, string name)
    {
        Object (key: key, name: name);
    }
}

} /* namespace Scores */
} /* namespace Games */
