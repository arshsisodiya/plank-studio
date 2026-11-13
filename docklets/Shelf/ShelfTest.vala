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

/**
 * Unit tests for the Shelf's side-effect free logic: URI handling, the
 * persistent store and the navigation stack. The panel and dock item are not
 * exercised here; they need a live dock and are covered by manual testing.
 */
namespace Docky {
  namespace ShelfTests {
    public static void register_tests () {
      Test.add_func ("/Shelf/Utils/file-from-uri", test_file_from_uri);
      Test.add_func ("/Shelf/Utils/entry-from-uri", test_entry_from_uri);
      Test.add_func ("/Shelf/Store/roundtrip", test_store_roundtrip);
      Test.add_func ("/Shelf/Store/duplicates", test_store_duplicates);
      Test.add_func ("/Shelf/Store/rejects", test_store_rejects);
      Test.add_func ("/Shelf/Store/malformed", test_store_malformed);
      Test.add_func ("/Shelf/Store/remove-clear", test_store_remove_clear);
      Test.add_func ("/Shelf/Path/navigation", test_path_navigation);
      Test.add_func ("/Shelf/Preferences/size", test_preferences_size);
    }

    private static ShelfPreferences make_prefs (string name) {
      var file = Paths.AppConfigFolder.get_child (name);
      try {
        file.delete ();
      } catch {}

      return new ShelfPreferences.with_file (file);
    }

    private static Gee.ArrayList<string> uri_list (string[] values) {
      var uris = new Gee.ArrayList<string> ();
      foreach (unowned string value in values)
        uris.add (value);

      return uris;
    }

    private static void test_file_from_uri () {
      assert (ShelfUtils.file_from_uri ("file:///tmp/shelf-test") != null);
      assert (ShelfUtils.file_from_uri ("/tmp/shelf-test") != null);

      // A path and its URI form must canonicalize to the same file.
      var from_uri = ShelfUtils.file_from_uri ("file:///tmp/shelf-test");
      var from_path = ShelfUtils.file_from_uri ("/tmp/shelf-test");
      assert (from_uri != null && from_path != null);
      assert (from_uri.get_uri () == from_path.get_uri ());

      // Non-file schemes are not references the Shelf can hold.
      assert (ShelfUtils.file_from_uri ("trash://") == null);
      assert (ShelfUtils.file_from_uri ("recent:///") == null);
      assert (ShelfUtils.file_from_uri ("docklet://shelf") == null);
      assert (ShelfUtils.file_from_uri ("search://foo") == null);
      assert (ShelfUtils.file_from_uri ("") == null);
      assert (ShelfUtils.file_from_uri ("   ") == null);
    }

    private static void test_entry_from_uri () {
      var entry = ShelfUtils.entry_from_uri ("file:///tmp/shelf-entry");
      assert (entry != null);
      assert (entry.uri == "file:///tmp/shelf-entry");
      assert (!entry.kind_known);
      assert (entry.display_name == "shelf-entry");

      assert (ShelfUtils.entry_from_uri ("trash://") == null);
    }

    private static void test_store_roundtrip () {
      var prefs = make_prefs ("test_shelf_roundtrip.dockitem");
      var store = new ShelfStore (prefs);
      assert (store.count == 0);

      int duplicates;
      int rejected;
      var uris = uri_list ({
        "file:///tmp/shelf-a.txt",
        "file:///tmp/shelf-b",
        "/tmp/shelf-c"
      });
      int added = store.add_uris (uris, out duplicates, out rejected);
      assert (added == 3);
      assert (duplicates == 0);
      assert (rejected == 0);
      assert (store.count == 3);

      store.flush ();

      // A second store over the same preferences must see the same entries in
      // the same insertion order.
      var store2 = new ShelfStore (prefs);
      assert (store2.count == 3);

      var entries = store2.get_entries ();
      assert (entries[0].uri == "file:///tmp/shelf-a.txt");
      assert (entries[1].uri == "file:///tmp/shelf-b");
      assert (entries[2].uri == "file:///tmp/shelf-c");
    }

    private static void test_store_duplicates () {
      var prefs = make_prefs ("test_shelf_duplicates.dockitem");
      var store = new ShelfStore (prefs);

      int duplicates;
      int rejected;
      store.add_uris (uri_list ({ "file:///tmp/shelf-dup" }), out duplicates, out rejected);
      assert (duplicates == 0);
      assert (store.count == 1);

      // The same location written as a path must still be detected as a
      // duplicate of the URI form.
      int added = store.add_uris (uri_list ({ "/tmp/shelf-dup" }), out duplicates, out rejected);
      assert (added == 0);
      assert (duplicates == 1);
      assert (store.count == 1);
    }

    private static void test_store_rejects () {
      var prefs = make_prefs ("test_shelf_rejects.dockitem");
      var store = new ShelfStore (prefs);

      int duplicates;
      int rejected;
      var uris = uri_list ({
        "trash://",
        "recent:///",
        "docklet://shelf",
        "",
        "file:///tmp/shelf-ok"
      });
      int added = store.add_uris (uris, out duplicates, out rejected);
      assert (added == 1);
      assert (rejected == 4);
      assert (store.count == 1);
    }

    private static void test_store_malformed () {
      // A malformed value must never crash the loader, and must not be
      // silently replaced until the collection actually changes.
      var prefs = make_prefs ("test_shelf_malformed.dockitem");
      prefs.Items = "this is not a shelf payload";

      var store = new ShelfStore (prefs);
      assert (store.count == 0);
      assert (prefs.Items == "this is not a shelf payload");

      // A valid header with an undecodable body is treated as empty too.
      prefs.Items = "shelf:1:%%%%";
      var store2 = new ShelfStore (prefs);
      assert (store2.count == 0);
    }

    private static void test_store_remove_clear () {
      var prefs = make_prefs ("test_shelf_remove_clear.dockitem");
      var store = new ShelfStore (prefs);

      int duplicates;
      int rejected;
      store.add_uris (
        uri_list ({ "file:///tmp/shelf-x", "file:///tmp/shelf-y" }),
        out duplicates,
        out rejected
      );
      assert (store.count == 2);

      assert (store.remove (store.get_entries ()[0]));
      assert (store.count == 1);

      store.clear ();
      assert (store.count == 0);
      assert (!store.remove (new ShelfEntry (File.new_for_path ("/tmp/unknown"))));
    }

    private static void test_path_navigation () {
      var path = new ShelfPath ();
      assert (path.is_root);
      assert (path.current == null);
      assert (path.depth == 0);

      var a = File.new_for_path ("/tmp/shelf-path-a");
      var b = File.new_for_path ("/tmp/shelf-path-b");

      path.push (a);
      assert (!path.is_root);
      assert (path.current != null);
      assert (path.current.get_path () == "/tmp/shelf-path-a");
      assert (path.depth == 1);

      path.push (b);
      assert (path.current.get_path () == "/tmp/shelf-path-b");
      assert (path.depth == 2);

      assert (path.pop ());
      assert (path.current.get_path () == "/tmp/shelf-path-a");
      assert (path.depth == 1);

      path.push (b);
      path.truncate (1);
      assert (path.depth == 1);
      assert (path.current.get_path () == "/tmp/shelf-path-a");

      path.reset ();
      assert (path.is_root);
      assert (!path.pop ());
    }

    private static void test_preferences_size () {
      var prefs = make_prefs ("test_shelf_size.dockitem");
      assert (!prefs.FixedSize);
      assert (prefs.FixedWidth == 340);
      assert (prefs.FixedHeight == 320);

      prefs.FixedSize = true;
      prefs.FixedWidth = 420;
      prefs.FixedHeight = 380;

      // Reload from disk
      var reloaded = new ShelfPreferences.with_file (prefs.get_backing_file ());
      assert (reloaded.FixedSize);
      assert (reloaded.FixedWidth == 420);
      assert (reloaded.FixedHeight == 380);
    }
  }
}

public static int main (string[] args) {
  Test.init (ref args);
  Gtk.init (ref args);

  Paths.initialize ("test", "");

  Docky.ShelfTests.register_tests ();

  return Test.run ();
}
