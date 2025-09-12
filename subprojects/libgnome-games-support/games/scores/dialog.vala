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

private class Dialog : Adw.Dialog
{
    private Context context;
    private Category? active_category = null;
    private List<Category?> categories = null;
    private ListStore? score_model = null;

    private Adw.ToolbarView toolbar;
    private Gtk.Button? done_button = null;
    private Gtk.DropDown? drop_down = null;
    private Gtk.ColumnView? score_view;
    private Gtk.ColumnViewColumn? rank_column;
    private Gtk.ColumnViewColumn? score_column;
    private Gtk.ColumnViewColumn? player_column;

    private Style scores_style;
    private Score? new_high_score;
    private string? score_or_time;

    public Dialog (Context context, string category_type, Style style, Score? new_high_score, Category? current_cat, string icon_name)
    {
        this.context = context;
        this.new_high_score = new_high_score;

        Gtk.Builder builder = new Gtk.Builder ();
        toolbar = new Adw.ToolbarView ();
        Adw.HeaderBar headerbar = new Adw.HeaderBar ();
        headerbar.set_show_end_title_buttons (new_high_score == null);
        set_child (toolbar);
        toolbar.add_child (builder, headerbar, "top");
        set_content_width (400);
        set_content_height (500);

        if (!context.has_scores () && new_high_score == null)
        {
            /* Empty State */
            set_title (_("No scores yet"));

            Adw.StatusPage status_page = new Adw.StatusPage ();
            toolbar.add_child (builder, status_page, null);
            status_page.set_icon_name (icon_name + "-symbolic");
            status_page.set_description (_("Play some games and your scores will show up here."));
            status_page.add_css_class ("dim-label");

            return;
        }

        scores_style = style;
        categories = context.get_categories ();
        active_category = current_cat;

        if (active_category == null)
            active_category = new Category (categories.nth_data (0).key, categories.nth_data (0).name);
        
        score_or_time = "";
        string new_score_or_time = "";

        if (scores_style == Style.POINTS_GREATER_IS_BETTER || scores_style == Style.POINTS_LESS_IS_BETTER)
        {
            score_or_time = _("Score");
            new_score_or_time = _("New Score in");
        }
        else
        {
            score_or_time = _("Time");
            new_score_or_time = _("New Time in");
        }

        /* Decide what the title should be */
        categories = context.get_categories ();
        if (new_high_score != null)
        {
            var title_widget = new Adw.WindowTitle (_("Congratulations!"), @"$new_score_or_time $category_type $(active_category.name)");
            headerbar.set_title_widget (title_widget);

            /* Button in the top right corner, finishes the dialog */
            done_button = new Gtk.Button.with_label (_("Done"));
            done_button.add_css_class ("suggested-action");
            done_button.clicked.connect (() => this.close ());
            headerbar.pack_end (done_button);
        }
        else if (categories.length () == 1)
        {
            active_category = ((!) categories.first ()).data;
            set_title (active_category.name);
        }
        else
        {
            drop_down = new Gtk.DropDown.from_strings (load_categories ());
            drop_down.notify["selected"].connect(() => {
                var selected_index = drop_down.get_selected();
                if (selected_index != -1)
                    load_scores_for_category (categories.nth_data (selected_index));
            });
            for (int i = 0; i != categories.length (); i++)
            {
                var category = categories.nth_data (i);
                if (category == active_category)
                    drop_down.set_selected (i);
            }

            headerbar.set_title_widget (drop_down);
        }

        /* Add the data to the dialog */
        var scroll = new Gtk.ScrolledWindow ();
        score_view = new Gtk.ColumnView (null);
        score_view.set_reorderable (false);
        score_view.set_tab_behavior (ITEM);
        setup_columns ();
        load_scores_for_category (active_category);
        scroll.set_child (score_view);
        toolbar.add_child (builder, scroll, null);
    }

    /* load names of all categories into a string array */
    private string[] load_categories ()
    {
        string[] categories_array = {};

        categories.foreach ((x) => categories_array += x.name);

        return categories_array;
    }

    /*
     * Most of the code below is from gnome-mahjongg
     * Copyright 2010-2013 Robert Ancell
     * Copyright 2010-2025 Mahjongg Contributors
     */

    private void load_scores_for_category (Category category)
    {
        score_model.remove_all ();
        var best_n_scores = context.get_high_scores (category, 10);
        foreach (var score in best_n_scores) {
            score_model.append (score);
        }
        score_view.scroll_to (0, null, Gtk.ListScrollFlags.NONE, null);
        active_category = category;
    }

    private void setup_columns ()
    {
        set_up_rank_column ();
        set_up_score_column ();
        set_up_player_column ();
        score_view.append_column (rank_column);
        score_view.append_column (score_column);
        score_view.append_column (player_column);
        score_column.set_expand (true);
        score_column.set_fixed_width (0);
        player_column.set_expand (true);
        player_column.set_fixed_width (0);

        score_model = new ListStore (typeof (Score));
        var sort_model = new Gtk.SortListModel (score_model, score_view.sorter);
        score_view.model = new Gtk.NoSelection (sort_model);

        if (scores_style == Style.POINTS_LESS_IS_BETTER || scores_style == Style.TIME_LESS_IS_BETTER)
            score_view.sort_by_column (rank_column, Gtk.SortType.ASCENDING);
        else
            score_view.sort_by_column (rank_column, Gtk.SortType.DESCENDING);

        score_view.sorter.changed.connect (() => {
            /* Scroll to top when resorting */
            score_view.scroll_to (0, null, Gtk.ListScrollFlags.FOCUS, null);
        });
    }

    private static int rank_sorter_cb (Score entry1, Score entry2) {
        return (int) (entry1.score > entry2.score) - (int) (entry1.score < entry2.score);
    }

    private void set_up_rank_column () {
        var factory = new Gtk.SignalListItemFactory ();
        var sorter = new Gtk.MultiSorter ();

        factory.setup.connect ((factory, object) => {
            unowned var list_item = object as Gtk.ListItem;
            var label = new Gtk.Label (null) {
                width_chars = 3,
                xalign = 0
            };
            label.add_css_class ("caption");
            label.add_css_class ("numeric");
            list_item.child = label;
        });
        factory.bind.connect ((factory, object) => {
            unowned var list_item = object as Gtk.ListItem;
            unowned var label = list_item.child as Gtk.Label;
            unowned var score = list_item.item as Score;
            uint position;
            score_model.find (score, out position);

            if (score == new_high_score)
                    label.add_css_class ("heading");

            label.label = (position + 1).to_string ();
        });
        sorter.append (new Gtk.CustomSorter ((CompareDataFunc<Score>) rank_sorter_cb));

        rank_column = new Gtk.ColumnViewColumn ("Rank", factory);
        rank_column.sorter = sorter;
    }

    private void set_up_score_column () {
        var factory = new Gtk.SignalListItemFactory ();

        factory.setup.connect ((factory, object) => {
            unowned var list_item = object as Gtk.ListItem;
            var label = new Gtk.Inscription (null);

            label.add_css_class ("numeric");
            list_item.child = label;
        });
        if (scores_style == Style.POINTS_GREATER_IS_BETTER || scores_style == Style.POINTS_LESS_IS_BETTER)
        {
            factory.bind.connect ((factory, object) => {
                unowned var list_item = object as Gtk.ListItem;
                unowned var label = list_item.child as Gtk.Inscription;
                unowned var score = list_item.item as Score;

                if (score == new_high_score)
                    label.add_css_class ("heading");

                label.text = score.score.to_string ();
            });
        }
        else
        {
            factory.bind.connect ((factory, object) => {
                unowned var list_item = object as Gtk.ListItem;
                unowned var label = list_item.child as Gtk.Inscription;
                unowned var score = list_item.item as Score;
                string time_label = "%lds".printf (score.score);
                if (score.score >= 60)
                    time_label = "%ldm %lds".printf (score.score / 60, score.score % 60);

                if (score == new_high_score)
                    label.add_css_class ("heading");

                label.text = time_label;
            });
        }

        score_column = new Gtk.ColumnViewColumn (score_or_time, factory);
        score_column.sorter = rank_column.sorter;
    }

    private void set_up_player_column () {
        var factory = new Gtk.SignalListItemFactory ();

        factory.bind.connect ((factory, object) => {
            unowned var list_item = object as Gtk.ListItem;
            unowned var score = list_item.item as Score;

            if (score == new_high_score)
            {
                var entry = new Gtk.Entry ();
                entry.text = score.user;
                entry.set_has_frame (false);
                entry.add_css_class ("heading");
                entry.notify["text"].connect (() => {
                    context.update_score_name (score, active_category, entry.get_text ());
                    score.user = entry.get_text ();
                });
                entry.activate.connect (() => this.close ());
                list_item.child = entry;
                this.set_focus (score_view);
                entry.grab_focus ();
                score_view.scroll_to (list_item.get_position (), null, Gtk.ListScrollFlags.NONE, null);
            }
            else
            {
                list_item.child = new Gtk.Inscription (score.user);
            }
        });

        player_column = new Gtk.ColumnViewColumn (_("Player"), factory);
    }

    internal void add_bottom_buttons (Context.NewGameFunc new_game_func, Context.QuitAppFunc quit_app_func)
    {
        var builder = new Gtk.Builder ();
        Gtk.CenterBox bottom_bar = new Gtk.CenterBox ();
        Gtk.Button new_game_button = new Gtk.Button.with_label (_("_New Game"));
        new_game_button.set_use_underline (true);
        new_game_button.set_can_shrink (true);
        new_game_button.clicked.connect (() => {
            this.close ();
            new_game_func ();
        });
        Gtk.Button quit_button = new Gtk.Button ();
        quit_button.set_can_shrink (true);
        Adw.ButtonContent content = new Adw.ButtonContent ();
        content.set_icon_name ("application-exit-symbolic");
        content.set_label (_("_Quit"));
        content.set_use_underline (true);
        content.set_can_shrink (true);
        quit_button.set_child (content);
        quit_button.clicked.connect (() => {
            this.close ();
            quit_app_func ();
        });
        new_game_button.add_css_class ("pill");
        quit_button.add_css_class ("toolbar");
        bottom_bar.add_css_class ("toolbar");
        bottom_bar.add_child (builder, new_game_button, "center");
        bottom_bar.add_child (builder, quit_button, "end");
        toolbar.add_child (builder, bottom_bar, "bottom");
    }
}

} /* namespace Scores */
} /* namespace Games */
