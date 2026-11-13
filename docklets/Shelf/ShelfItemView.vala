//
// Copyright (C) 2024 Plank Reloaded Developers
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Docky {
  /**
   * Renders a collection of {@link ShelfEntry} as either a grid of tiles or a
   * compact list, switching between the two with a {@link Gtk.Stack}.
   */
  public class ShelfItemView : Gtk.Stack {
    /** A tile was activated. */
    public signal void entry_activated (ShelfEntry entry);

    /** A context menu was requested for a tile. */
    public signal void entry_context_menu (ShelfEntry entry, Gdk.EventButton event);

    /** A tile asked to reveal its containing folder. */
    public signal void entry_open_containing (ShelfEntry entry);

    /** A tile entry was dragged out and dropped. */
    public signal void entry_drag_dropped_out (ShelfEntry entry);

    private Gtk.FlowBox grid_box;
    private Gtk.ListBox list_box;
    private Gtk.ScrolledWindow grid_scroll;
    private Gtk.ScrolledWindow list_scroll;

    private Gee.HashMap<ShelfEntry, Gee.ArrayList<ShelfTile>> tiles =
      new Gee.HashMap<ShelfEntry, Gee.ArrayList<ShelfTile>> ();

    private bool use_list = false;

    public ShelfItemView () {
      GLib.Object ();
    }

    construct {
      transition_type = Gtk.StackTransitionType.CROSSFADE;
      transition_duration = 120;

      grid_box = new Gtk.FlowBox ();
      grid_box.selection_mode = Gtk.SelectionMode.NONE;
      grid_box.activate_on_single_click = false;
      grid_box.homogeneous = true;
      grid_box.max_children_per_line = 5;
      grid_box.min_children_per_line = 1;
      grid_box.row_spacing = 4;
      grid_box.column_spacing = 4;
      grid_box.valign = Gtk.Align.START;
      grid_box.halign = Gtk.Align.FILL;

      grid_scroll = new Gtk.ScrolledWindow (null, null);
      grid_scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
      grid_scroll.set_propagate_natural_width (true);
      grid_scroll.set_propagate_natural_height (true);
      grid_scroll.set_min_content_height (80);
      grid_scroll.add (grid_box);

      list_box = new Gtk.ListBox ();
      list_box.selection_mode = Gtk.SelectionMode.NONE;
      list_box.activate_on_single_click = false;
      list_box.valign = Gtk.Align.START;
      list_box.halign = Gtk.Align.FILL;

      list_scroll = new Gtk.ScrolledWindow (null, null);
      list_scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
      list_scroll.set_propagate_natural_width (true);
      list_scroll.set_propagate_natural_height (true);
      list_scroll.set_min_content_height (80);
      list_scroll.add (list_box);

      add_named (grid_scroll, "grid");
      add_named (list_scroll, "list");
    }

    /** Empties both views. */
    public void clear () {
      foreach (var child in grid_box.get_children ())
        child.destroy ();

      foreach (var child in list_box.get_children ())
        child.destroy ();

      tiles.clear ();
    }

    /** Replaces the current contents. */
    public void set_entries (Gee.ArrayList<ShelfEntry> entries) {
      clear ();

      foreach (var entry in entries)
        append_entry (entry);
    }

    /** Appends a single entry to both views. */
    public void append_entry (ShelfEntry entry) {
      var grid_tile = new ShelfTile (entry, false);
      connect_tile (grid_tile);
      var grid_child = new Gtk.FlowBoxChild ();
      grid_child.add (grid_tile);
      grid_box.add (grid_child);

      var list_tile = new ShelfTile (entry, true);
      connect_tile (list_tile);
      var list_row = new Gtk.ListBoxRow ();
      list_row.activatable = false;
      list_row.selectable = false;
      list_row.get_style_context ().add_class ("shelf-list-row");
      list_row.add (list_tile);
      list_box.add (list_row);

      var entry_tiles = new Gee.ArrayList<ShelfTile> ();
      entry_tiles.add (grid_tile);
      entry_tiles.add (list_tile);
      tiles[entry] = entry_tiles;

      grid_child.show_all ();
      list_row.show_all ();
    }

    /** Refreshes the tiles showing a single entry after it was validated. */
    public void refresh_entry (ShelfEntry entry) {
      var entry_tiles = tiles[entry];
      if (entry_tiles == null)
        return;

      foreach (var tile in entry_tiles)
        tile.refresh ();
    }

    /** Selects the grid or list presentation. */
    public void set_list_mode (bool list) {
      use_list = list;
      set_visible_child_name (list ? "list" : "grid");
    }

    public bool list_mode {
      get { return use_list; }
    }

    /** Caps how tall the scrollable content is allowed to grow. */
    public void set_max_content_height (int height) {
      grid_scroll.set_max_content_height (height);
      list_scroll.set_max_content_height (height);
    }

    /** Sets whether scrollable views propagate their natural height. */
    public void set_propagate_natural_height (bool propagate) {
      grid_scroll.set_propagate_natural_height (propagate);
      list_scroll.set_propagate_natural_height (propagate);
    }

    private void connect_tile (ShelfTile tile) {
      tile.activated.connect ((entry) => entry_activated (entry));
      tile.context_menu_requested.connect ((entry, event) => entry_context_menu (entry, event));
      tile.open_containing_requested.connect ((entry) => entry_open_containing (entry));
      tile.drag_dropped_out.connect ((entry) => entry_drag_dropped_out (entry));
    }
  }
}
