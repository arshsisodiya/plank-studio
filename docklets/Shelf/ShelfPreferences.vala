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
   * Preferences stored in each Shelf .dockitem file.
   *
   * The item references are kept in a single serialized string because Plank
   * preferences only support scalar values, enums, colors and Serializable
   * objects. This keeps the on-disk format self contained and versioned.
   */
  public class ShelfPreferences : DockItemPreferences {
    [Description (nick = "items",
                  blurb = "Serialized references collected by this Shelf.")]
    public string Items { get; set; default = ""; }

    [Description (nick = "use-list-view",
                  blurb = "Show the Shelf contents as a compact list.")]
    public bool UseListView { get; set; default = false; }

    [Description (nick = "pinned",
                  blurb = "Keep the Shelf panel open until it is closed explicitly.")]
    public bool Pinned { get; set; default = false; }

    [Description (nick = "fixed-size",
                  blurb = "Maintain fixed dimensions instead of dynamic sizing.")]
    public bool FixedSize { get; set; default = false; }

    [Description (nick = "fixed-width",
                  blurb = "Width when fixed size is enabled.")]
    public int FixedWidth { get; set; default = 340; }

    [Description (nick = "fixed-height",
                  blurb = "Height when fixed size is enabled.")]
    public int FixedHeight { get; set; default = 320; }

    public ShelfPreferences.with_file (GLib.File file) {
      base.with_file (file);
    }

    protected override void reset_properties () {
      base.reset_properties ();
      Items = "";
      UseListView = false;
      Pinned = false;
      FixedSize = false;
      FixedWidth = 340;
      FixedHeight = 320;
    }
  }
}
