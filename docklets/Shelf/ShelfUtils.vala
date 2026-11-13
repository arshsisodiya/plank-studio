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
   * Small, side-effect free helpers shared by the Shelf implementation.
   */
  public class ShelfUtils : GLib.Object {
    private static bool css_installed = false;

    /**
     * Turns a URI or absolute path into a canonical local File.
     *
     * Non-file schemes (trash://, recent://, docklet://, ...) are rejected
     * because the Shelf only references real local filesystem locations.
     */
    public static File? file_from_uri (string raw) {
      var value = raw.strip ();
      if (value == "")
        return null;

      File file = value.has_prefix ("/")
        ? File.new_for_path (value)
        : File.new_for_uri (value);

      if (file.get_uri_scheme () != "file")
        return null;

      var path = file.get_path ();
      if (path == null || path == "")
        return null;

      // Canonicalize so the same file always hashes to the same URI.
      return File.new_for_uri (file.get_uri ());
    }

    public static ShelfEntry? entry_from_uri (string uri, bool is_directory = false, bool kind_known = false) {
      var file = file_from_uri (uri);
      if (file == null)
        return null;

      return new ShelfEntry (file, is_directory, kind_known);
    }

    public static Gee.ArrayList<string> extract_uris (Gtk.SelectionData selection_data) {
      var uris = new Gee.ArrayList<string> ();

      var direct = selection_data.get_uris ();
      if (direct.length > 0) {
        foreach (unowned string uri in direct)
          if (uri != null && uri.strip () != "")
            uris.add (uri);
        return uris;
      }

      unowned uint8[] raw = selection_data.get_data_with_length ();
      if (raw.length <= 0)
        return uris;

      var nul_terminated = new uint8[raw.length + 1];
      Memory.copy (nul_terminated, raw, raw.length);
      nul_terminated[raw.length] = 0;

      foreach (unowned string uri in Uri.list_extract_uris ((string) nul_terminated))
        if (uri != null && uri.strip () != "")
          uris.add (uri);

      return uris;
    }

    public static string item_count_text (int count) {
      return ngettext ("%d item", "%d items", count).printf (count);
    }

    public static void ensure_css (Gdk.Screen screen) {
      if (css_installed)
        return;

      var provider = new Gtk.CssProvider ();
      try {
        provider.load_from_data (SHELF_CSS, -1);
      } catch (Error e) {
        warning ("Unable to load Shelf styles: %s", e.message);
        return;
      }

      Gtk.StyleContext.add_provider_for_screen (
        screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
      css_installed = true;
    }

    private const string SHELF_CSS = """
window.shelf-window {
  background-color: transparent;
}

.shelf-panel {
  background-color: transparent;
  border: none;
  box-shadow: none;
  color: rgba(255, 255, 255, 0.94);
}

.shelf-header {
  padding: 14px 18px 8px 18px;
}

.shelf-title {
  font-size: 15px;
  font-weight: bold;
  color: #ffffff;
}

.shelf-count {
  font-size: 13px;
  color: rgba(255, 255, 255, 0.55);
}

.shelf-header-button {
  background-image: none;
  background-color: transparent;
  border: none;
  box-shadow: none;
  padding: 4px;
  min-width: 22px;
  min-height: 22px;
  border-radius: 7px;
  color: rgba(255, 255, 255, 0.72);
}

.shelf-header-button:hover {
  background-color: rgba(255, 255, 255, 0.10);
  color: #ffffff;
}

.shelf-header-button:checked {
  background-color: rgba(92, 162, 255, 0.24);
  color: #ffffff;
}

.shelf-nav {
  padding: 0 18px 8px 18px;
}

.shelf-back-button {
  background-image: none;
  background-color: transparent;
  border: none;
  box-shadow: none;
  padding: 3px;
  min-width: 20px;
  min-height: 20px;
  border-radius: 6px;
  color: rgba(255, 255, 255, 0.75);
}

.shelf-back-button:hover {
  background-color: rgba(255, 255, 255, 0.12);
  color: #ffffff;
}

.shelf-back-button:disabled {
  color: rgba(255, 255, 255, 0.22);
}

.shelf-crumb {
  background-image: none;
  background-color: transparent;
  border: none;
  box-shadow: none;
  padding: 2px 4px;
  border-radius: 5px;
  font-size: 11px;
  color: rgba(255, 255, 255, 0.58);
}

.shelf-crumb:hover {
  background-color: rgba(255, 255, 255, 0.08);
  color: #ffffff;
}

.shelf-crumb-current {
  color: rgba(255, 255, 255, 0.96);
  font-weight: bold;
}

.shelf-separator {
  color: rgba(255, 255, 255, 0.24);
  font-size: 11px;
}

.shelf-content {
  padding: 0 12px;
}

.shelf-tile {
  background-color: transparent;
  border-radius: 10px;
  padding: 8px 6px;
  transition: background-color 120ms ease;
}

.shelf-tile:hover {
  background-color: rgba(255, 255, 255, 0.10);
}

.shelf-tile:active {
  background-color: rgba(255, 255, 255, 0.16);
}

.shelf-tile-name {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.94);
}

.shelf-tile-meta {
  font-size: 10px;
  color: rgba(255, 255, 255, 0.42);
}

.shelf-missing .shelf-tile-name {
  color: rgba(255, 255, 255, 0.40);
}

.shelf-hidden {
  opacity: 0.62;
}

.shelf-list-row {
  background-color: transparent;
  padding: 0;
}

.shelf-list-row:hover {
  background-color: transparent;
}

.shelf-list-tile {
  padding: 5px 8px;
}

.shelf-empty-box {
  border: 2px dashed rgba(255, 255, 255, 0.18);
  border-radius: 14px;
  margin: 10px 14px 14px 14px;
  padding: 34px 16px;
  transition: all 150ms ease-in-out;
}

.shelf-empty-box.drag-hover {
  border-color: #3584e4;
  background-color: rgba(53, 132, 228, 0.09);
}

.shelf-empty-title {
  font-size: 15px;
  font-weight: bold;
  color: rgba(255, 255, 255, 0.95);
  margin-top: 10px;
}

.shelf-empty-subtitle {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.55);
  margin-top: 4px;
}

.shelf-error-detail {
  font-size: 10px;
  color: rgba(255, 255, 255, 0.40);
}

.shelf-footer {
  padding: 8px 16px 12px 16px;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
}

.shelf-status {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.48);
}

.shelf-footer-button {
  background-image: none;
  background-color: transparent;
  border: none;
  box-shadow: none;
  padding: 3px 7px;
  border-radius: 6px;
  font-size: 11px;
  color: rgba(255, 255, 255, 0.68);
}

.shelf-footer-button:hover {
  background-color: rgba(255, 255, 255, 0.09);
  color: #ffffff;
}

.shelf-clear-button {
  background-image: none;
  background-color: transparent;
  border: none;
  box-shadow: none;
  padding: 4px 8px;
  border-radius: 6px;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.70);
}

.shelf-clear-button:hover {
  background-color: rgba(255, 255, 255, 0.10);
  color: #ffffff;
}

.shelf-truncated {
  color: rgba(255, 199, 110, 0.92);
}

.shelf-resize-banner {
  background-color: rgba(30, 36, 45, 0.95);
  border: 1px solid rgba(53, 132, 228, 0.65);
  border-radius: 9px;
  margin: 6px 14px;
  padding: 6px 10px;
}

.shelf-resize-label {
  font-size: 11px;
  color: #5ca2ff;
  font-weight: bold;
}

.shelf-resize-dim {
  font-size: 10px;
  color: rgba(255, 255, 255, 0.65);
}

.shelf-lock-button {
  background-image: none;
  background-color: #3584e4;
  color: #ffffff;
  border-radius: 6px;
  padding: 3px 9px;
  font-size: 11px;
  font-weight: bold;
  border: none;
  box-shadow: none;
}

.shelf-lock-button:hover {
  background-color: #4b9bfa;
}

.shelf-size-button {
  background-image: none;
  background-color: transparent;
  color: rgba(255, 255, 255, 0.55);
  border: none;
  box-shadow: none;
  font-size: 11px;
  padding: 3px 6px;
  border-radius: 5px;
}

.shelf-size-button:hover {
  background-color: rgba(255, 255, 255, 0.10);
  color: #ffffff;
}
""";
  }
}
