//
//  Copyright (C) 2026 Plank Reloaded
//
//  This file is part of Plank.
//
//  Plank is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Plank is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

using Plank;

namespace PlankTests {
  /**
   * Regression tests for provider-level drag-and-drop URI validation and pinning.
   */
  public static int main (string[] args) {
    Test.init (ref args);
    Gtk.init (ref args);

    Log.set_always_fatal (LogLevelFlags.LEVEL_ERROR | LogLevelFlags.LEVEL_CRITICAL);

    Paths.initialize ("test", Config.DATA_DIR);
    Factory.item_factory = new ItemFactory ();

    Test.add_func ("/DnD/ApplicationDockItemProvider/drop_validation", dnd_application_provider_validation);
    Test.add_func ("/DnD/DefaultApplicationDockItemProvider/transient_drop", dnd_default_provider_transient_drop);

    return Test.run ();
  }

  File create_unique_dir (string prefix) {
    var dir = Paths.AppConfigFolder.get_child ("%s-%s".printf (prefix, GLib.get_real_time ().to_string ()));
    Paths.ensure_directory_exists (dir);
    return dir;
  }

  void dnd_application_provider_validation () {
    var dir = create_unique_dir ("test_appprovider_dnd");
    var provider = new ApplicationDockItemProvider (dir);
    var app_uri = File.new_for_path (Config.DATA_DIR + "/test.desktop").get_uri ();
    var folder_uri = dir.get_uri ();
    var missing_uri = dir.get_child ("definitely_missing_plank_test_item.txt").get_uri ();

    var bad_http = new Gee.ArrayList<string> ();
    bad_http.add ("https://example.com/item");
    assert (provider.can_accept_drop (bad_http) == false);
    assert (provider.accept_drop (bad_http) == false);

    var bad_missing = new Gee.ArrayList<string> ();
    bad_missing.add (missing_uri);
    assert (provider.can_accept_drop (bad_missing) == false);
    assert (provider.accept_drop (bad_missing) == false);

    var valid_app = new Gee.ArrayList<string> ();
    valid_app.add (app_uri);
    assert (provider.can_accept_drop (valid_app) == true);
    assert (provider.accept_drop (valid_app) == true);
    assert (provider.item_exists_for_uri (app_uri) == true);

    assert (provider.can_accept_drop (valid_app) == false);
    assert (provider.accept_drop (valid_app) == false);

    var mixed_with_folder = new Gee.ArrayList<string> ();
    mixed_with_folder.add (app_uri);
    mixed_with_folder.add (folder_uri);
    assert (provider.can_accept_drop (mixed_with_folder) == true);
    assert (provider.accept_drop (mixed_with_folder) == true);
    assert (provider.item_exists_for_uri (folder_uri) == true);
  }

  void dnd_default_provider_transient_drop () {
    var suffix = GLib.get_real_time ().to_string ();
    var dir = create_unique_dir ("test_defaultprovider_dnd");
    var prefs = new DockPreferences ("test-dnd-default-" + suffix);
    var provider = new DefaultApplicationDockItemProvider (prefs, dir);
    var app_uri = File.new_for_path (Config.DATA_DIR + "/test.desktop").get_uri ();

    var transient = new TransientDockItem.with_launcher (app_uri);
    provider.add (transient);
    assert (provider.item_for_uri (app_uri) is TransientDockItem);

    var uris = new Gee.ArrayList<string> ();
    uris.add (app_uri);
    assert (provider.can_accept_drop (uris) == true);
    assert (provider.accept_drop (uris) == true);
    assert (provider.item_for_uri (app_uri) != null);
    assert (!(provider.item_for_uri (app_uri) is TransientDockItem));

    bool found_dockitem = false;
    try {
      var enumerator = dir.enumerate_children (FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE);
      FileInfo? info;
      while ((info = enumerator.next_file ()) != null) {
        if (info.get_name ().has_suffix (".dockitem")) {
          found_dockitem = true;
          break;
        }
      }
    } catch (Error e) {
      assert_not_reached ();
    }
    assert (found_dockitem == true);
  }
}

