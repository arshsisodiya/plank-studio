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

using Plank;

namespace Docky {
  /**
   * A single clickable tile inside the Shelf panel.
   *
   * The tile is presentation only: activation, context menus and navigation
   * are decided by the panel through signals. It also acts as a drag source so
   * references can be dragged out to other applications as a copy/link.
   */
  public class ShelfTile : Gtk.EventBox {
    private const int GRID_ICON_SIZE = 48;
    private const int LIST_ICON_SIZE = 22;

    public ShelfEntry entry { get; construct; }
    public bool list_mode { get; construct; default = false; }

    /** The tile was activated with a primary click. */
    public signal void activated (ShelfEntry entry);

    /** A context menu was requested for the tile. */
    public signal void context_menu_requested (ShelfEntry entry, Gdk.EventButton event);

    /** The tile was activated with the middle mouse button. */
    public signal void open_containing_requested (ShelfEntry entry);

    /** The tile entry was dragged out and dropped. */
    public signal void drag_dropped_out (ShelfEntry entry);

    private Gtk.Image icon_image;
    private Gtk.Label name_label;
    private Gtk.Label? meta_label = null;
    private bool dragging = false;
    private bool drag_data_requested = false;
    private bool drag_failed_flag = false;
    private bool drag_delete_requested = false;

    public ShelfTile (ShelfEntry entry, bool list_mode) {
      GLib.Object (entry: entry, list_mode: list_mode);
    }

    construct {
      get_style_context ().add_class ("shelf-tile");
      set_visible_window (true);
      set_above_child (false);

      add_events (
        Gdk.EventMask.BUTTON_PRESS_MASK
        | Gdk.EventMask.BUTTON_RELEASE_MASK
        | Gdk.EventMask.ENTER_NOTIFY_MASK
        | Gdk.EventMask.LEAVE_NOTIFY_MASK
      );

      build ();
      refresh ();

      has_tooltip = true;
      query_tooltip.connect (on_query_tooltip);
      button_press_event.connect (on_button_press);
      button_release_event.connect (on_button_release);

      setup_drag_source ();
    }

    private void build () {
      int icon_size = list_mode ? LIST_ICON_SIZE : GRID_ICON_SIZE;

      icon_image = new Gtk.Image ();
      icon_image.set_pixel_size (icon_size);
      icon_image.halign = Gtk.Align.CENTER;
      icon_image.valign = Gtk.Align.CENTER;

      name_label = new Gtk.Label ("");
      name_label.get_style_context ().add_class ("shelf-tile-name");
      name_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
      name_label.use_markup = false;
      name_label.set_max_width_chars (list_mode ? 40 : 14);

      if (list_mode) {
        name_label.halign = Gtk.Align.START;
        name_label.valign = Gtk.Align.CENTER;
        name_label.xalign = 0.0f;
        name_label.lines = 1;

        var text_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        text_box.valign = Gtk.Align.CENTER;
        text_box.pack_start (name_label, false, false, 0);

        meta_label = new Gtk.Label ("");
        meta_label.get_style_context ().add_class ("shelf-tile-meta");
        meta_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
        meta_label.halign = Gtk.Align.START;
        meta_label.xalign = 0.0f;
        meta_label.lines = 1;
        text_box.pack_start (meta_label, false, false, 0);

        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        row.get_style_context ().add_class ("shelf-list-tile");
        row.pack_start (icon_image, false, false, 0);
        row.pack_start (text_box, true, true, 0);
        add (row);
      } else {
        name_label.halign = Gtk.Align.CENTER;
        name_label.valign = Gtk.Align.START;
        name_label.justify = Gtk.Justification.CENTER;
        name_label.set_line_wrap (true);
        name_label.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
        name_label.lines = 2;
        name_label.set_max_width_chars (12);

        var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        column.set_size_request (68, -1);
        column.pack_start (icon_image, false, false, 0);
        column.pack_start (name_label, false, false, 0);
        add (column);
      }

      show_all ();
    }

    /** Re-reads the entry and updates icon, labels and state classes. */
    public void refresh () {
      var context = get_style_context ();
      context.remove_class ("shelf-missing");
      context.remove_class ("shelf-hidden");

      if (entry.is_missing)
        context.add_class ("shelf-missing");
      else if (entry.is_hidden)
        context.add_class ("shelf-hidden");

      icon_image.set_from_pixbuf (
        DrawingService.load_icon (
          entry.effective_icon (),
          list_mode ? LIST_ICON_SIZE : GRID_ICON_SIZE,
          list_mode ? LIST_ICON_SIZE : GRID_ICON_SIZE
        )
      );

      name_label.label = entry.display_name;

      if (meta_label != null)
        meta_label.label = meta_text ();
    }

    private string meta_text () {
      if (entry.is_missing)
        return _("Missing");

      var path = entry.file.get_path () ?? "";
      if (path == "")
        return "";

      var parent = entry.file.get_parent ();
      var parent_path = parent != null ? (parent.get_path () ?? "") : "";
      if (parent_path == "")
        return path;

      return parent_path;
    }

    private bool on_button_press (Gdk.EventButton event) {
      if (event.button == 3) {
        context_menu_requested (entry, event);
        return true;
      }

      return false;
    }

    private bool on_button_release (Gdk.EventButton event) {
      if (event.button == 1) {
        if (!dragging)
          activated (entry);
        return true;
      }

      if (event.button == 2) {
        open_containing_requested (entry);
        return true;
      }

      return false;
    }

    private bool on_query_tooltip (int x, int y, bool keyboard_mode, Gtk.Tooltip tooltip) {
      tooltip.set_text (entry.tooltip_text ());
      return true;
    }

    private void setup_drag_source () {
      Gtk.TargetEntry te = { "text/uri-list", 0, 0 };

      Gtk.drag_source_set (
        this,
        Gdk.ModifierType.BUTTON1_MASK,
        { te },
        Gdk.DragAction.COPY | Gdk.DragAction.MOVE | Gdk.DragAction.LINK
      );

      drag_begin.connect (on_drag_begin);
      drag_end.connect (on_drag_end);
      drag_data_get.connect (on_drag_data_get);
      drag_data_delete.connect (on_drag_data_delete);
      drag_failed.connect (on_drag_failed);
    }

    private void on_drag_begin (Gdk.DragContext context) {
      dragging = true;
      drag_data_requested = false;
      drag_failed_flag = false;
      drag_delete_requested = false;

      var pixbuf = DrawingService.load_icon (
        entry.effective_icon (), LIST_ICON_SIZE, LIST_ICON_SIZE);
      if (pixbuf != null)
        Gtk.drag_set_icon_pixbuf (context, pixbuf, 4, 4);
    }

    private void on_drag_data_get (
      Gdk.DragContext context,
      Gtk.SelectionData selection_data,
      uint info,
      uint time_
    ) {
      drag_data_requested = true;
      selection_data.set_uris ({ entry.uri });
    }

    private void on_drag_data_delete (Gdk.DragContext context) {
      drag_delete_requested = true;
    }

    private bool on_drag_failed (Gdk.DragContext context, Gtk.DragResult result) {
      drag_failed_flag = true;
      return false;
    }

    private void on_drag_end (Gdk.DragContext context) {
      dragging = false;

      unowned Gdk.Window? dest_win = context.get_dest_window ();
      var toplevel = get_toplevel ();
      unowned Gdk.Window? toplevel_win = toplevel != null ? toplevel.get_window () : null;
      bool dropped_on_self = (dest_win != null && toplevel_win != null && dest_win == toplevel_win);

      bool drop_succeeded = !dropped_on_self && (
        drag_delete_requested ||
        (!drag_failed_flag && drag_data_requested && context.get_selected_action () != 0)
      );

      if (drop_succeeded) {
        drag_dropped_out (entry);
      }
    }
  }
}
