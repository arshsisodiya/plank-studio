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
   * The navigation stack for the Shelf panel. An empty stack means the root
   * collection; each node is a real folder being browsed.
   */
  public class ShelfPath : GLib.Object {
    private Gee.ArrayList<File> nodes = new Gee.ArrayList<File> ();

    public bool is_root {
      get { return nodes.size == 0; }
    }

    public File? current {
      owned get {
        if (nodes.size == 0)
          return null;

        return nodes[nodes.size - 1];
      }
    }

    public int depth {
      get { return nodes.size; }
    }

    public void push (File folder) {
      nodes.add (folder);
    }

    public bool pop () {
      if (nodes.size == 0)
        return false;

      nodes.remove_at (nodes.size - 1);
      return true;
    }

    public void reset () {
      nodes.clear ();
    }

    public Gee.ArrayList<File> get_nodes () {
      return nodes;
    }

    public void truncate (int length) {
      while (nodes.size > length)
        nodes.remove_at (nodes.size - 1);
    }
  }
}
