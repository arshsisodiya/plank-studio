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
   * The dock item for a Shelf.
   *
   * The item itself is deliberately thin: it owns the persistent
   * {@link ShelfStore} and a lazily created {@link ShelfPanel}, draws the
   * bundled icon, shows a count badge and accepts file/folder drops. All of
   * the heavy lifting lives in the panel and the store so the dock's main
   * loop is never blocked.
   */
  public class ShelfDockItem : DockletItem {
    private const string SHELF_ICON =
      "resource://" + G_RESOURCE_PATH + "/icons/shelf.svg";

    private const string VALIDATE_ATTRIBUTES =
      FileAttribute.STANDARD_TYPE + ","
      + FileAttribute.STANDARD_NAME + ","
      + FileAttribute.STANDARD_DISPLAY_NAME + ","
      + FileAttribute.STANDARD_ICON + ","
      + FileAttribute.STANDARD_IS_HIDDEN;

    private ShelfStore store;
    private ShelfPanel? panel = null;
    private uint spring_open_timer_id = 0U;

    private bool removed = false;
    private bool connected = true;
    private Cancellable? validate_cancellable = null;

    private ShelfPreferences shelf_prefs {
      get { return (ShelfPreferences) Prefs; }
    }

    public ShelfDockItem.with_dockitem_file (GLib.File file) {
      GLib.Object (Prefs: new ShelfPreferences.with_file (file));
    }

    construct {
      store = new ShelfStore (shelf_prefs);
      store.changed.connect (on_store_changed);

      notify["Container"].connect (handle_container_changed);
      deleted.connect (handle_deleted);

      Icon = SHELF_ICON;
      Text = _("Shelf");

      update_count ();
    }

    ~ShelfDockItem () {
      teardown ();
    }

    private void handle_container_changed () {
      if (Container == null)
        removed_from_dock ();
    }

    private void handle_deleted () {
      removed_from_dock ();
    }

    // Teardown cannot rely on the destructor alone: the store's signal and the
    // panel both hold references back to this item, forming a cycle that would
    // keep it (and the panel) alive forever. Breaking it on removal lets the
    // item finalize normally.
    private void removed_from_dock () {
      removed = true;
      teardown ();
    }

    private void teardown () {
      if (spring_open_timer_id > 0U) {
        GLib.Source.remove (spring_open_timer_id);
        spring_open_timer_id = 0U;
      }

      if (validate_cancellable != null) {
        validate_cancellable.cancel ();
        validate_cancellable = null;
      }

      if (connected) {
        connected = false;
        store.changed.disconnect (on_store_changed);
      }

      if (panel != null) {
        panel.close_panel ();
        panel.detach ();
        panel.destroy ();
        panel = null;
      }
    }

    private void on_store_changed () {
      update_count ();
    }

    private void update_count () {
      var count = store.count;
      Count = count;
      CountVisible = count > 0;
    }

    private ShelfPanel ensure_panel () {
      if (panel == null)
        panel = new ShelfPanel (store, shelf_prefs);

      return panel;
    }

    private void toggle_panel (uint32 event_time) {
      var shelf = ensure_panel ();

      if (shelf.is_open) {
        shelf.close_panel ();
        return;
      }

      unowned DockController? dock = get_dock ();
      if (dock != null) {
        unowned PositionManager pm = dock.position_manager;

        // get_hover_region_for_element is dock-window relative, so shift it
        // into root coordinates before handing it to the panel.
        var icon = pm.get_hover_region_for_element (this);
        var win = pm.get_dock_window_region ();
        icon.x += win.x;
        icon.y += win.y;

        shelf.set_anchor (icon, pm.get_monitor_geometry (), dock.prefs.Position);
      }

      shelf.open (event_time);
    }

    private void show_panel () {
      var shelf = ensure_panel ();
      if (shelf.is_open)
        return;

      unowned DockController? dock = get_dock ();
      if (dock != null) {
        unowned PositionManager pm = dock.position_manager;

        var icon = pm.get_hover_region_for_element (this);
        var win = pm.get_dock_window_region ();
        icon.x += win.x;
        icon.y += win.y;

        shelf.set_anchor (icon, pm.get_monitor_geometry (), dock.prefs.Position);
      }

      shelf.open (Gtk.get_current_event_time ());
    }

    private void open_panel () {
      show_panel ();
    }

    protected override AnimationType on_clicked (
      PopupButton button,
      Gdk.ModifierType mod,
      uint32 event_time
    ) {
      if (button != PopupButton.LEFT)
        return AnimationType.NONE;

      toggle_panel (event_time);
      return AnimationType.NONE;
    }

    public override string get_drop_text () {
      return _("Drop to add to Shelf");
    }

    public override bool can_accept_drop (Gee.ArrayList<string> uris) {
      // Runs on every pointer motion during an external drag, so it must stay
      // I/O free; the actual drop reports anything that cannot be added.
      foreach (var uri in uris) {
        if (uri == null || uri == "")
          continue;

        if (ShelfUtils.file_from_uri (uri) != null) {
          // Spring-load: if the user hovers over the Shelf dock item with files,
          // open the panel automatically so they can see and drop into the panel.
          if (panel == null || !panel.is_open) {
            if (spring_open_timer_id == 0U) {
              spring_open_timer_id = GLib.Timeout.add (300, () => {
                spring_open_timer_id = 0U;
                if (!removed)
                  open_panel ();
                return false;
              });
            }
          }
          return true;
        }
      }

      return false;
    }

    public override bool accept_drop (Gee.ArrayList<string> uris) {
      if (spring_open_timer_id > 0U) {
        GLib.Source.remove (spring_open_timer_id);
        spring_open_timer_id = 0U;
      }

      if (removed)
        return false;

      int duplicates = 0;
      int rejected = 0;
      int added = store.add_uris (uris, out duplicates, out rejected);

      if (added > 0) {
        // Resolve names/icons for anything new so the persisted kind is
        // correct even if the panel is never opened.
        validate_pending_entries.begin ();
        return true;
      }

      // Treat an all-duplicate drop as accepted so the drag completes cleanly.
      return duplicates > 0;
    }

    /**
     * Resolves metadata for references whose kind is not known yet. The panel
     * does the same for the root collection, but doing it here keeps a drop
     * that happens while the panel is closed correctly persisted.
     */
    private async void validate_pending_entries () {
      if (validate_cancellable != null)
        validate_cancellable.cancel ();

      var cancellable = new Cancellable ();
      validate_cancellable = cancellable;

      var snapshot = new Gee.ArrayList<ShelfEntry> ();
      snapshot.add_all (store.get_entries ());

      foreach (var entry in snapshot) {
        if (removed || cancellable.is_cancelled ())
          return;

        if (entry.kind_known)
          continue;

        try {
          var info = yield entry.file.query_info_async (
            VALIDATE_ATTRIBUTES,
            FileQueryInfoFlags.NONE,
            Priority.DEFAULT,
            cancellable
          );

          if (removed || cancellable.is_cancelled ())
            return;

          entry.apply_info (info);
        } catch (Error e) {
          if (removed || e is IOError.CANCELLED)
            return;

          entry.kind_known = true;
          entry.mark_missing ();
        }

        store.entry_updated (entry);
      }
    }

    public override Gee.ArrayList<Gtk.MenuItem> get_menu_items () {
      var items = new Gee.ArrayList<Gtk.MenuItem> ();

      var open_item = create_menu_item (_("_Open Shelf"), SHELF_ICON);
      open_item.activate.connect (open_panel);
      items.add (open_item);

      var clear_item = create_menu_item (_("_Clear Shelf"), "edit-clear");
      clear_item.sensitive = store.count > 0;
      clear_item.activate.connect (() => store.clear ());
      items.add (clear_item);

      items.add (new Gtk.SeparatorMenuItem ());

      var size_menu_item = create_menu_item (_("Size Settings"), "zoom-fit-best-symbolic");
      var size_submenu = new Gtk.Menu ();
      size_menu_item.set_submenu (size_submenu);

      var dynamic_item = new Gtk.RadioMenuItem.with_label (null, _("Dynamic Size (Default)"));
      dynamic_item.active = !shelf_prefs.FixedSize;
      dynamic_item.toggled.connect (() => {
        if (dynamic_item.active) {
          if (panel != null)
            panel.set_fixed_size_mode (false);
          else
            shelf_prefs.FixedSize = false;
        }
      });
      size_submenu.append (dynamic_item);

      var fixed_item = new Gtk.RadioMenuItem.with_label_from_widget (dynamic_item, _("Fixed Size"));
      fixed_item.active = shelf_prefs.FixedSize;
      fixed_item.toggled.connect (() => {
        if (fixed_item.active) {
          if (panel != null)
            panel.set_fixed_size_mode (true);
          else
            shelf_prefs.FixedSize = true;
        }
      });
      size_submenu.append (fixed_item);

      size_submenu.append (new Gtk.SeparatorMenuItem ());

      var edit_size_item = create_menu_item (_("Edit Size"), "preferences-system-symbolic");
      edit_size_item.activate.connect (() => {
        show_panel ();
        if (panel != null)
          panel.start_resize_mode ();
      });
      size_submenu.append (edit_size_item);

      var lock_size_item = create_menu_item (_("Lock Size"), "changes-prevent-symbolic");
      lock_size_item.sensitive = (panel != null && panel.is_resizing);
      lock_size_item.activate.connect (() => {
        if (panel != null)
          panel.lock_current_size ();
      });
      size_submenu.append (lock_size_item);

      items.add (size_menu_item);

      return items;
    }
  }
}
