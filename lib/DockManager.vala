//
// Copyright (C) 2026 Plank Reloaded Developers
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
   * Owns the registry of configured docks and performs lifecycle operations
   * (create, duplicate, rename, enable/disable and delete) on them.
   *
   * The registry is kept in the main schema:
   *  - known-docks: every dock the user has configured, enabled or not
   *  - enabled-docks: the docks which are running (also the startup source)
   */
  public class DockManager : GLib.Object {
    /**
     * The maximum number of docks Plank will create or keep configured.
     */
    public const int MAX_DOCKS = 8;

    public signal void docks_changed ();

    public AbstractMain app { get; construct; }

    GLib.Settings settings;

    /**
     * Creates a dock manager for the given application.
     */
    public DockManager (AbstractMain app) {
      Object (app: app);
    }

    construct {
      settings = create_settings ("net.launchpad.plank");
      sync_registry ();
    }

    static string[] to_array (Gee.Collection<string> values) {
      var result = new string[values.size];
      var i = 0;
      foreach (var value in values)
        result[i++] = value;
      return result;
    }

    static Gee.ArrayList<string> to_list (string[] values) {
      var result = new Gee.ArrayList<string> ();
      foreach (unowned string value in values)
        result.add (value);
      return result;
    }

    /**
     * Returns the next free stable dock id, or null if all ids are in use.
     *
     * @param used the ids which are already taken
     */
    public static string? next_dock_id (Gee.Collection<string> used) {
      for (var i = 1; i <= MAX_DOCKS * 4; i++) {
        var candidate = "dock%d".printf (i);
        if (!used.contains (candidate))
          return candidate;
      }

      return null;
    }

    static GLib.Settings dock_settings (string dock_id) {
      return create_settings ("net.launchpad.plank.dock.settings",
                              "/net/launchpad/plank/docks/%s/".printf (dock_id));
    }

    void sync_registry () {
      var known = to_list (settings.get_strv ("known-docks"));
      var enabled = to_list (settings.get_strv ("enabled-docks"));

      // A configuration from before multiple docks existed has no
      // known-docks list; dock1 is its dock. Do not re-add dock1 when the
      // user has deliberately removed it and kept another dock.
      if (known.size == 0)
        known.add ("dock1");

      // Never leave every dock disabled
      if (enabled.size == 0)
        enabled.add (known[0]);

      foreach (var id in enabled)
        if (!known.contains (id))
          known.add (id);

      // Keep the registry bounded, but never drop a running dock. Trim the
      // enabled list first so docks cut from it can be dropped from known.
      while (enabled.size > MAX_DOCKS)
        enabled.remove_at (enabled.size - 1);

      while (known.size > MAX_DOCKS) {
        var removed = false;
        for (var i = known.size - 1; i >= 0; i--) {
          if (!enabled.contains (known[i])) {
            known.remove_at (i);
            removed = true;
            break;
          }
        }
        if (!removed)
          break;
      }

      settings.set_strv ("known-docks", to_array (known));
      settings.set_strv ("enabled-docks", to_array (enabled));
    }

    void persist (Gee.List<string> known, Gee.List<string> enabled) {
      settings.set_strv ("known-docks", to_array (known));
      settings.set_strv ("enabled-docks", to_array (enabled));
    }

    Gee.ArrayList<string> known_docks () {
      return to_list (settings.get_strv ("known-docks"));
    }

    Gee.ArrayList<string> enabled_docks () {
      return to_list (settings.get_strv ("enabled-docks"));
    }

    /**
     * All configured docks, including disabled ones, in display order.
     */
    public string[] get_known_docks () {
      return settings.get_strv ("known-docks");
    }

    /**
     * The docks which are currently running.
     */
    public string[] get_enabled_docks () {
      return settings.get_strv ("enabled-docks");
    }

    public bool is_enabled (string dock_id) {
      foreach (unowned string id in settings.get_strv ("enabled-docks"))
        if (id == dock_id)
          return true;
      return false;
    }

    public bool is_known (string dock_id) {
      foreach (unowned string id in settings.get_strv ("known-docks"))
        if (id == dock_id)
          return true;
      return false;
    }

    /**
     * The friendly name for a dock, falling back to its stable id.
     */
    public string get_display_name (string dock_id) {
      // A running dock keeps the name in memory and updates it synchronously
      // when it is renamed; the settings backend may report the old value
      // until the write has been flushed.
      var controller = app.find_dock (dock_id);
      if (controller != null)
        return controller.prefs.display_name ();

      var display = dock_settings (dock_id).get_string ("display-name").strip ();
      return (display != "" ? display : dock_id);
    }

    /**
     * Whether docks are automatically nudged apart when they overlap.
     */
    public bool get_avoid_overlap () {
      return settings.get_boolean ("avoid-dock-overlap");
    }

    public void set_avoid_overlap (bool avoid) {
      if (settings.get_boolean ("avoid-dock-overlap") == avoid)
        return;

      settings.set_boolean ("avoid-dock-overlap", avoid);
      app.relayout_docks ();
    }

    /**
     * Creates a new, empty dock and enables it.
     *
     * @param display_name an optional friendly name
     * @return the new dock id, or null if no dock could be created
     */
    public string? create_dock (string display_name = "") {
      var known = known_docks ();
      var enabled = enabled_docks ();

      if (known.size >= MAX_DOCKS)
        return null;

      var dock_id = next_dock_id (known);
      if (dock_id == null)
        return null;

      var config_folder = Paths.AppConfigFolder.get_child (dock_id);
      Paths.ensure_directory_exists (config_folder);

      var dock_prefs = dock_settings (dock_id);
      var name = display_name.strip ();
      if (name != "")
        dock_prefs.set_string ("display-name", name);

      known.add (dock_id);
      enabled.add (dock_id);
      persist (known, enabled);

      app.add_dock (app.create_dock (dock_id));

      docks_changed ();
      return dock_id;
    }

    /**
     * Duplicates a dock's settings and items into a new, independent dock.
     *
     * @param dock_id the dock to copy
     * @return the new dock id, or null on failure
     */
    public string? duplicate_dock (string dock_id) {
      var known = known_docks ();
      var enabled = enabled_docks ();

      if (!known.contains (dock_id) || known.size >= MAX_DOCKS)
        return null;

      var new_id = next_dock_id (known);
      if (new_id == null)
        return null;

      var source_folder = Paths.AppConfigFolder.get_child (dock_id);
      var target_folder = Paths.AppConfigFolder.get_child (new_id);
      Paths.ensure_directory_exists (target_folder);

      if (!copy_directory (source_folder, target_folder)) {
        warning ("Unable to copy the configuration of dock '%s'", dock_id);
        delete_directory (target_folder);
        return null;
      }

      copy_settings (dock_id, new_id);

      var target_prefs = dock_settings (new_id);
      var source_name = get_display_name (dock_id);
      target_prefs.set_string ("display-name", _("%s (copy)").printf (source_name));

      known.add (new_id);
      enabled.add (new_id);
      persist (known, enabled);

      app.add_dock (app.create_dock (new_id));

      docks_changed ();
      return new_id;
    }

    /**
     * Renames a dock. Only the friendly display name changes; its id and
     * configuration path stay the same.
     */
    public bool rename_dock (string dock_id, string display_name) {
      if (!is_known (dock_id))
        return false;

      var name = display_name.strip ();
      var prefs = dock_settings (dock_id);
      prefs.set_string ("display-name", name);

      var controller = app.find_dock (dock_id);
      if (controller != null)
        controller.prefs.DisplayName = name;

      docks_changed ();
      return true;
    }

    /**
     * Enables or disables a dock. Disabling stops and removes the running
     * controller while keeping its configuration for later.
     *
     * @return false if the change was refused (e.g. the last enabled dock)
     */
    public bool set_enabled (string dock_id, bool enable) {
      if (!is_known (dock_id))
        return false;

      var known = known_docks ();
      var enabled = enabled_docks ();
      var currently_enabled = enabled.contains (dock_id);

      if (currently_enabled == enable)
        return true;

      if (!enable) {
        if (enabled.size <= 1)
          return false;

        enabled.remove (dock_id);
        persist (known, enabled);

        var controller = app.find_dock (dock_id);
        if (controller != null)
          app.remove_dock (controller);
      } else {
        if (enabled.size >= MAX_DOCKS)
          return false;

        enabled.add (dock_id);
        persist (known, enabled);

        if (app.find_dock (dock_id) == null)
          app.add_dock (app.create_dock (dock_id));
      }

      docks_changed ();
      return true;
    }

    /**
     * Deletes a dock, its configuration folder and its stored settings.
     * The last remaining dock cannot be deleted.
     */
    public bool delete_dock (string dock_id) {
      var known = known_docks ();
      var enabled = enabled_docks ();

      if (!known.contains (dock_id))
        return false;

      if (enabled.contains (dock_id) && enabled.size <= 1)
        return false;

      if (known.size <= 1)
        return false;

      var controller = app.find_dock (dock_id);
      if (controller != null)
        app.remove_dock (controller);

      enabled.remove (dock_id);
      known.remove (dock_id);
      persist (known, enabled);

      var prefs = dock_settings (dock_id);
      foreach (unowned string key in prefs.settings_schema.list_keys ())
        prefs.reset (key);
      GLib.Settings.sync ();

      delete_directory (Paths.AppConfigFolder.get_child (dock_id));

      docks_changed ();
      return true;
    }

    void copy_settings (string source_id, string target_id) {
      var source = dock_settings (source_id);
      var target = dock_settings (target_id);

      foreach (unowned string key in source.settings_schema.list_keys ())
        target.set_value (key, source.get_value (key));

      GLib.Settings.sync ();
    }

    static bool copy_directory (File source, File target) {
      try {
        if (!target.query_exists ())
          target.make_directory_with_parents ();

        var enumerator = source.enumerate_children (
          FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
          FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

        FileInfo? info;
        while ((info = enumerator.next_file ()) != null) {
          var source_child = source.get_child (info.get_name ());
          var target_child = target.get_child (info.get_name ());

          if (info.get_file_type () == FileType.DIRECTORY) {
            if (!copy_directory (source_child, target_child))
              return false;
          } else {
            source_child.copy (target_child, FileCopyFlags.OVERWRITE, null, null);
          }
        }
      } catch (Error e) {
        warning ("Unable to copy '%s' to '%s': %s", source.get_path (), target.get_path (), e.message);
        return false;
      }

      return true;
    }

    static bool delete_directory (File directory) {
      if (!directory.query_exists ())
        return true;

      try {
        var enumerator = directory.enumerate_children (
          FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
          FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

        FileInfo? info;
        while ((info = enumerator.next_file ()) != null) {
          var child = directory.get_child (info.get_name ());
          if (info.get_file_type () == FileType.DIRECTORY)
            delete_directory (child);
          else
            child.delete ();
        }

        directory.delete ();
      } catch (Error e) {
        warning ("Unable to delete '%s': %s", directory.get_path (), e.message);
        return false;
      }

      return true;
    }
  }
}
