//
// Copyright (C) 2011 Robert Dyer, Rico Tzschichholz
//
// This file is part of Plank.
//
// Plank is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Plank is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Plank {
  /**
   * A dock item for the dock itself.  Has things like about, help, quit etc.
   */
  public class PlankDockItem : DockItem {
    /**
     * The dock this item belongs to, used to open the right preferences.
     */
    public DockController? controller { get; construct; }

    public PlankDockItem (DockController? controller = null) {
      GLib.Object (Prefs : new DockItemPreferences (), Text: "Plank", Icon: "plank",
                   controller: controller);
    }

    construct
    {
      // if plank is pinned indicate that it is running while it isnt user-visible
      Indicator = IndicatorState.SINGLE;
    }

    static void activate_app_action (string action_name) {
      unowned GLib.Application? app = Application.get_default ();
      if (app != null)
        app.activate_action (action_name, null);
    }

    static void activate_preferences (string? dock_name) {
      unowned GLib.Application? app = Application.get_default ();
      if (app == null)
        return;

      if (dock_name != null)
        app.activate_action ("preferences-for-dock", new Variant.string (dock_name));
      else
        app.activate_action ("preferences", null);
    }

    void show_preferences () {
      activate_preferences (controller != null ? controller.name : null);
    }

    /**
     * {@inheritDoc}
     */
    public override bool can_be_removed () {
      return false;
    }

    /**
     * {@inheritDoc}
     */
    protected override AnimationType on_clicked (PopupButton button, Gdk.ModifierType mod, uint32 event_time) {
      show_preferences ();

      return AnimationType.DARKEN;
    }

    /**
     * {@inheritDoc}
     */
    public override Gee.ArrayList<Gtk.MenuItem> get_menu_items () {
      var items = new Gee.ArrayList<Gtk.MenuItem> ();
      // Capture dock_name locally rather than referencing `this` in signal
      // handlers; otherwise transient instances from get_item_for_dock() are
      // unreffed immediately and g_signal_connect_object disconnects every item.
      string? dock_name = controller != null ? controller.name : null;

      var item = create_menu_item (_("Get _Help Online..."), "help-browser");
      item.activate.connect (() => activate_app_action ("help"));
      items.add (item);

      item = create_menu_item (_("_Translate This Application..."), "preferences-desktop-locale");
      item.activate.connect (() => activate_app_action ("translate"));
      items.add (item);

      items.add (new Gtk.SeparatorMenuItem ());

      item = create_menu_item (_("_Preferences"), "preferences-system");
      item.activate.connect (() => activate_preferences (dock_name));
      items.add (item);

      item = create_menu_item (_("_About"), "help-about");
      item.activate.connect (() => activate_app_action ("about"));
      items.add (item);

      // No explicit quit-item on elementary OS
      if (!environment_is_session_desktop (XdgSessionDesktop.PANTHEON)) {
        items.add (new Gtk.SeparatorMenuItem ());

        item = create_menu_item (_("_Quit"), "application-exit");
        item.activate.connect (() => activate_app_action ("quit"));
        items.add (item);
      }

      return items;
    }
  }
}
