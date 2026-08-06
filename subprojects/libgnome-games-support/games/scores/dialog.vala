/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright © 2014 Nikhar Agrawal
 * Copyright © 2014-2026 libgnome-games-support Contributors
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

private const string DIALOG_STYLE = """
dialog.scores columnview {
    background: transparent;
}

dialog.scores columnview header button,
dialog.scores columnview row cell {
    padding-left: 12px;
    padding-right: 12px;
}
""";

private class Dialog : Adw.Dialog
{
    private Context context;
    private Category? active_category = null;
    private ListStore? score_model = null;

    private Adw.ToolbarView toolbar;
    private Adw.HeaderBar headerbar;
    private Gtk.Button? new_game_button = null;
    private Gtk.DropDown? drop_down = null;
    private Gtk.ColumnView? score_view;
    private Gtk.ColumnViewColumn? rank_column;
    private Gtk.ColumnViewColumn? score_column;
    private Gtk.ColumnViewColumn? player_column;
    private Gtk.Entry? player_entry;
    private Category[] categories;

    private Style scores_style;
    private Score? new_high_score;
    private string? score_type;
    private string category_type;

    public AddScoreAction action { get; set; default = AddScoreAction.NONE; }

    public Dialog (Context context,
                   string category_type,
                   Style style,
                   Score? new_high_score,
                   Category? current_cat,
                   string icon_name,
                   string? score_type)
    {
        this.context = context;
        this.new_high_score = new_high_score;
        this.category_type = category_type;

        toolbar = new Adw.ToolbarView ();
        headerbar = new Adw.HeaderBar ();
        set_child (toolbar);
        toolbar.add_top_bar (headerbar);
        set_content_width (400);
        set_content_height (500);

        if (!context.has_scores () && new_high_score == null)
        {
            /* Empty State */
            set_title (_("No scores yet"));

            Adw.StatusPage status_page = new Adw.StatusPage ();
            toolbar.set_content (status_page);
            status_page.set_icon_name (icon_name + "-symbolic");
            status_page.set_description (_("Play some games and your scores will show up here."));
            status_page.add_css_class ("dim-label");

            return;
        }

        if (new_high_score == null)
        {
            var delete_button = new Gtk.Button.from_icon_name ("user-trash-symbolic");
            delete_button.tooltip_text = _("Clear Scores…");
            delete_button.clicked.connect (show_clear_scores_dialog);
            headerbar.pack_start (delete_button);
        }

        scores_style = style;

        categories = context.get_categories ();
        active_category = current_cat;

        add_css_class ("scores");

        if (active_category == null)
            active_category = new Category (categories[0].key, categories[0].name);

        this.score_type = "";
        string new_score_or_time = "";

        if (scores_style == Style.POINTS_GREATER_IS_BETTER || scores_style == Style.POINTS_LESS_IS_BETTER)
        {
            /* Translators: %1$s is the category type, %2$s is the category (e.g. "New Score for Level: 1") */
            new_score_or_time = _("New Score for %1$s: %2$s").printf (category_type, active_category.name);
            this.score_type = _("Score");
        }
        else
        {
            /* Translators: %1$s is the category type, %2$s is the category (e.g. "New Time for Level: 1") */
            new_score_or_time = _("New Time for %1$s: %2$s").printf (category_type, active_category.name);
            this.score_type = _("Time");
        }

        if (score_type != null)
            this.score_type = score_type;

        /* Decide what the title should be */
        if (new_high_score != null)
        {
            var title_widget = new Adw.WindowTitle (_("Congratulations!"), new_score_or_time);
            headerbar.set_title_widget (title_widget);
        }
        else if (categories.length == 1)
        {
            active_category = categories[0];
            /* Translators: %1$s is the category type, %2$s is the category (e.g. "Level: 1") */
            set_title (_("%1$s: %2$s").printf (category_type, active_category.name));
        }
        else
        {
            drop_down = new Gtk.DropDown.from_strings (category_names (categories));
            var list_factory = drop_down.get_factory ();
            var button_factory = new Gtk.SignalListItemFactory ();

            button_factory.setup.connect ((factory, object) => {
                unowned var list_item = object as Gtk.ListItem;

                list_item.child = new Gtk.Label (null) {
                    ellipsize = Pango.EllipsizeMode.END,
                    xalign = 0
                };
            });
            button_factory.bind.connect (drop_down_button_cb);

            drop_down.set_factory (button_factory);
            drop_down.set_list_factory (list_factory);

            for (int i = 0; i != categories.length; i++)
            {
                var category = categories[i];
                if (category.key == active_category.key)
                    drop_down.set_selected (i);
            }

            drop_down.notify["selected"].connect (drop_down_selected_cb);

            unowned var button = drop_down.get_first_child () as Gtk.Button;
            button.has_frame = false;

            unowned var popover = drop_down.get_last_child () as Gtk.Popover;
            popover.halign = Gtk.Align.CENTER;

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
        toolbar.set_content (scroll);
        if (drop_down != null)
            this.focus_widget = drop_down;
        else
            this.focus_widget = score_view;
    }

    private void drop_down_selected_cb ()
    {
        var selected_index = drop_down.get_selected ();
        if (selected_index != -1)
            load_scores_for_category (categories[selected_index]);
    }

    private void drop_down_button_cb (Gtk.SignalListItemFactory factory, Object object)
    {
        unowned var list_item = object as Gtk.ListItem;
        unowned var string_object = list_item.item as Gtk.StringObject;
        unowned var label = list_item.child as Gtk.Label;

        /* Translators: %1$s is the category type, %2$s is the category (e.g. "Level: 1") */
        label.label = _("%1$s: %2$s").printf (category_type, string_object.@string);
    }

    /* load names of all categories into a string array */
    private string[] category_names (Category[] categories)
    {
        string[] categories_array = {};

        foreach (var cat in categories) { categories_array += cat.name; }

        return categories_array;
    }

    private void load_scores_for_category (Category category)
    {
        score_model.remove_all ();
        var best_n_scores = context.get_high_scores (category);
        foreach (var score in best_n_scores)
            score_model.append (score);

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
        score_view.sort_by_column (rank_column, Gtk.SortType.ASCENDING);

        score_view.sorter.changed.connect (() => {
            /* Scroll to top when resorting */
            score_view.scroll_to (0, null, Gtk.ListScrollFlags.FOCUS, null);
        });

        if (new_high_score == null)
            return;

        var controller = new Gtk.EventControllerFocus ();
        controller.enter.connect (() => {
            Idle.add (() => {
                score_view.scroll_to (new_high_score.rank - 1, null, Gtk.ListScrollFlags.FOCUS, null);
                player_entry.grab_focus ();
                return false;
            });
        });
        score_view.add_controller (controller);
    }

    private void set_up_rank_column () {
        var factory = new Gtk.SignalListItemFactory ();
        var sorter = new Gtk.MultiSorter ();

        factory.setup.connect ((factory, object) => {
            unowned var list_item = object as Gtk.ListItem;
            var label = new Gtk.Inscription (null);
            label.add_css_class ("caption");
            label.add_css_class ("numeric");
            label.xalign = 0.5f;
            list_item.child = label;
        });
        factory.bind.connect ((factory, object) => {
            unowned var list_item = object as Gtk.ListItem;
            unowned var label = list_item.child as Gtk.Inscription;
            unowned var score = list_item.item as Score;

            label.text = score.rank.to_string ();
        });

        if (scores_style == Style.POINTS_GREATER_IS_BETTER || scores_style == Style.TIME_GREATER_IS_BETTER)
            sorter.append (new Gtk.CustomSorter ((CompareDataFunc<Score>) Score.score_greater_sorter));
        else
            sorter.append (new Gtk.CustomSorter ((CompareDataFunc<Score>) Score.score_less_sorter));

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

                label.text = "%'ld".printf (score.score);
            });
        }
        else
        {
            factory.bind.connect ((factory, object) => {
                unowned var list_item = object as Gtk.ListItem;
                unowned var label = list_item.child as Gtk.Inscription;
                unowned var score = list_item.item as Score;

                if (score.score >= 60)
                    label.text = "%ldm %lds".printf (score.score / 60, score.score % 60);
                else
                    label.text = "%lds".printf (score.score);
            });
        }

        score_column = new Gtk.ColumnViewColumn (score_type, factory);
        score_column.sorter = rank_column.sorter;
    }

    private void set_up_player_column () {
        var factory = new Gtk.SignalListItemFactory ();

        factory.bind.connect ((factory, object) => {
            unowned var list_item = object as Gtk.ListItem;
            unowned var score = list_item.item as Score;

            if (score == new_high_score)
            {
                player_entry = new Gtk.Entry ();
                player_entry.text = score.user;
                player_entry.set_has_frame (false);
                player_entry.add_css_class ("heading");
                player_entry.notify["text"].connect (() => {
                    context.update_score_name (score, active_category, player_entry.get_text ());
                    score.user = player_entry.get_text ();
                });
                player_entry.activate.connect (() => {
                    if (new_game_button != null)
                        new_game_button.activate ();
                    else
                        this.close ();
                });

                list_item.child = player_entry;
            }
            else
            {
                var label = new Gtk.Inscription (score.user);
                label.has_tooltip = true;
                label.query_tooltip.connect ((x, y, keyboard_tooltip, tooltip) => {
                    tooltip.set_text ("%s\n%s\n%s".printf (
                        score.user, score.get_user_extra_info (), new DateTime.from_unix_utc (score.time).format ("%x")
                    ));
                    return true;
                });
                list_item.child = label;
            }
        });
        if (new_high_score != null)
        {
            factory.unbind.connect ((factory, object) => {
                unowned var list_item = object as Gtk.ListItem;
                unowned var score = list_item.item as Score;

                if (score == new_high_score)
                    player_entry = null;
            });
        }

        player_column = new Gtk.ColumnViewColumn (_("Player"), factory);
    }

    internal void add_bottom_buttons ()
    {
        headerbar.set_show_end_title_buttons (true);
        new_game_button = new Gtk.Button.with_label (_("_New Game")) {
            can_shrink = true,
            use_underline = true
        };
        new_game_button.clicked.connect (() => {
            this.action = AddScoreAction.NEW_GAME;
            this.close ();
        });

        Adw.ButtonContent quit_button_content = new Adw.ButtonContent () {
            icon_name = "application-exit-symbolic",
            label = _("_Quit"),
            use_underline = true,
            can_shrink = true
        };
        Gtk.Button quit_button = new Gtk.Button () {
            child = quit_button_content,
            can_shrink = true,
            valign = Gtk.Align.CENTER
        };
        quit_button.clicked.connect (() => {
            this.action = AddScoreAction.QUIT;
            this.close ();
        });

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        var bottom_bar = new Gtk.CenterBox () {
            hexpand = true,
            center_widget = new_game_button,
            end_widget = quit_button
        };
        box.append (bottom_bar);

        new_game_button.add_css_class ("pill");
        new_game_button.add_css_class ("suggested-action");
        box.add_css_class ("toolbar");
        bottom_bar.add_css_class ("toolbar");
        toolbar.add_bottom_bar (box);
    }

    private async void show_clear_scores_dialog ()
    {
        var dialog = new Adw.AlertDialog (
            _("Clear All Scores?"),
            _("This will clear every score for every layout.")
        );
        dialog.default_response = "cancel";
        dialog.add_response ("cancel", _("_Cancel"));
        dialog.add_response ("clear", _("Clear All"));
        dialog.set_response_appearance ("clear", Adw.ResponseAppearance.DESTRUCTIVE);

        var response = yield dialog.choose (this, null);
        if (response == "clear")
        {
            this.close ();
            context.delete_scores.begin ((obj, res) => {
                try
                {
                    context.delete_scores.end (res);
                }
                catch (Error e)
                {
                    warning ("Failed to delete scores: %s", e.message);
                }
            });
        }
    }
}

} /* namespace Scores */
} /* namespace Games */
