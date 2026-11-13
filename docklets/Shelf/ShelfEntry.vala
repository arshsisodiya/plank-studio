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
   * A reference to a file or folder held by a Shelf.
   *
   * Only the URI and the cached kind are persisted. Names and icons are
   * always refreshed from the real file so a moved or renamed item cannot
   * leave stale metadata behind.
   */
  public class ShelfEntry : GLib.Object {
    public File file { get; construct; }

    public string uri {
      owned get { return file.get_uri (); }
    }

    public bool is_directory { get; set; default = false; }
    public bool kind_known { get; set; default = false; }
    public bool is_missing { get; set; default = false; }
    public bool is_hidden { get; set; default = false; }
    public string display_name { get; set; default = ""; }
    public string icon_name { get; set; default = ""; }

    public ShelfEntry (File file, bool is_directory = false, bool kind_known = false) {
      string? basename = file.get_basename ();
      string? path = file.get_path ();

      GLib.Object (
        file: file,
        is_directory: is_directory,
        kind_known: kind_known,
        display_name: (basename != null && basename != "" ? basename : (path ?? file.get_uri ())),
        icon_name: is_directory ? "folder" : "text-x-generic",
        is_hidden: (basename != null && basename.has_prefix ("."))
      );
    }

    public string effective_icon () {
      if (is_missing)
        return "image-missing";

      if (icon_name != null && icon_name != "")
        return icon_name;

      return is_directory ? "folder" : "text-x-generic";
    }

    public void apply_info (FileInfo info) {
      kind_known = true;
      is_missing = false;
      is_directory = info.get_file_type () == FileType.DIRECTORY;
      is_hidden = info.get_is_hidden ();

      var name = info.get_display_name ();
      if (name != null && name != "")
        display_name = name;

      var icon = DrawingService.get_icon_from_gicon (info.get_icon ());
      if (icon != null && icon != "")
        icon_name = icon;
      else
        icon_name = is_directory ? "folder" : "text-x-generic";
    }

    public void mark_missing () {
      is_missing = true;
      if (display_name == null || display_name == "") {
        string? basename = file.get_basename ();
        string? path = file.get_path ();
        display_name = basename != null && basename != ""
          ? basename
          : (path ?? file.get_uri ());
      }
    }

    public string tooltip_text () {
      var path = file.get_path () ?? file.get_uri ();
      if (is_missing)
        return _("Missing: %s").printf (path);
      if (is_directory)
        return _("Folder: %s").printf (path);
      return path;
    }
  }
}
