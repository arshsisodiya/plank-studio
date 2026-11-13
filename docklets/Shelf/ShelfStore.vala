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
   * The persistent collection of references held by a Shelf.
   *
   * Only the URI and a cached kind flag are stored. Names, icons and missing
   * state are always re-derived from the real file so a moved or renamed item
   * can never leave stale metadata behind.
   */
  public class ShelfStore : GLib.Object {
    private const string FORMAT_PREFIX = "shelf:1:";
    private const uint SYNC_DELAY_MS = 400U;

    private ShelfPreferences prefs;
    private Gee.ArrayList<ShelfEntry> entries = new Gee.ArrayList<ShelfEntry> ();

    private uint sync_timer_id = 0U;
    private bool pending_sync = false;

    /** Emitted whenever the collection changes. */
    public signal void changed ();

    public ShelfStore (ShelfPreferences prefs) {
      this.prefs = prefs;
      load ();
    }

    ~ShelfStore () {
      flush ();
    }

    public int count {
      get { return entries.size; }
    }

    public Gee.ArrayList<ShelfEntry> get_entries () {
      return entries;
    }

    public bool contains_uri (string uri) {
      foreach (var entry in entries)
        if (entry.uri == uri)
          return true;

      return false;
    }

    /**
     * Adds references from raw URIs, ignoring anything that is not a local
     * file and anything already present.
     *
     * @param uris the URIs to add
     * @param duplicates number of URIs already held by the Shelf
     * @param rejected number of URIs that are not local files
     * @return the number of references actually added
     */
    public int add_uris (Gee.ArrayList<string> uris, out int duplicates, out int rejected) {
      duplicates = 0;
      rejected = 0;
      int added = 0;

      foreach (var uri in uris) {
        var entry = ShelfUtils.entry_from_uri (uri, false, false);
        if (entry == null) {
          rejected++;
          continue;
        }

        if (contains_uri (entry.uri)) {
          duplicates++;
          continue;
        }

        entries.add (entry);
        added++;
      }

      if (added > 0) {
        queue_sync ();
        changed ();
      }

      return added;
    }

    public bool remove (ShelfEntry entry) {
      if (!entries.remove (entry))
        return false;

      queue_sync ();
      changed ();
      return true;
    }

    public void clear () {
      if (entries.size == 0)
        return;

      entries.clear ();
      queue_sync ();
      changed ();
    }

    /**
     * Records that an entry's cached kind changed after it was validated.
     * The caller is responsible for emitting a redraw.
     */
    public void entry_updated (ShelfEntry entry) {
      if (!contains_uri (entry.uri))
        return;

      queue_sync ();
    }

    /** Writes the current collection to preferences immediately. */
    public void flush () {
      if (sync_timer_id > 0U) {
        GLib.Source.remove (sync_timer_id);
        sync_timer_id = 0U;
      }

      if (!pending_sync)
        return;

      pending_sync = false;
      prefs.Items = serialize ();
    }

    private void queue_sync () {
      pending_sync = true;

      if (sync_timer_id > 0U)
        return;

      // Coalesce bursts (validation of a large shelf, rapid removals) into a
      // single write so the preferences file is not rewritten for every entry.
      sync_timer_id = GLib.Timeout.add (SYNC_DELAY_MS, () => {
        sync_timer_id = 0U;
        flush ();
        return false;
      });
    }

    private void load () {
      entries.clear ();

      var raw = prefs.Items ?? "";
      if (raw == "")
        return;

      if (!raw.has_prefix (FORMAT_PREFIX))
        return;

      var encoded = raw.substring (FORMAT_PREFIX.length);
      if (encoded == "")
        return;

      var decoded = (string) Base64.decode (encoded);
      if (decoded == "")
        return;

      foreach (var line in decoded.split ("\n")) {
        var trimmed = line.strip ();
        if (trimmed == "")
          continue;

        string flag;
        string uri;
        var tab = trimmed.index_of_char ('\t');
        if (tab < 0) {
          flag = "?";
          uri = trimmed;
        } else {
          flag = trimmed.substring (0, tab);
          uri = trimmed.substring (tab + 1);
        }

        bool kind_known = flag == "d" || flag == "f";
        bool is_directory = flag == "d";

        var entry = ShelfUtils.entry_from_uri (uri, is_directory, kind_known);
        if (entry == null)
          continue;

        if (contains_uri (entry.uri))
          continue;

        entries.add (entry);
      }
    }

    private string serialize () {
      var sb = new StringBuilder ();

      foreach (var entry in entries) {
        if (sb.len > 0)
          sb.append_c ('\n');

        sb.append_c (entry.kind_known ? (entry.is_directory ? 'd' : 'f') : '?');
        sb.append_c ('\t');
        sb.append (entry.uri);
      }

      var raw = sb.str;
      var bytes = new uint8[raw.length];
      for (int i = 0; i < raw.length; i++)
        bytes[i] = (uint8) raw[i];

      return FORMAT_PREFIX + Base64.encode (bytes);
    }
  }
}
