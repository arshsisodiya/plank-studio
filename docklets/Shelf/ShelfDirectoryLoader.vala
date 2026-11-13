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
   * Asynchronously enumerates a folder for the Shelf panel.
   *
   * Enumeration runs through GIO's async API so the dock's main loop is never
   * blocked. Results are sorted (folders first) and delivered in small
   * batches so very large folders can paint incrementally. A generation token
   * plus a {@link GLib.Cancellable} makes sure a stale enumeration can never
   * touch the panel after the user navigated away or closed it.
   */
  public class ShelfDirectoryLoader : GLib.Object {
    /** Hard cap on rendered entries to keep the panel responsive. */
    public const int MAX_ENTRIES = 2000;

    private const int ENUM_BATCH_SIZE = 128;
    private const int EMIT_BATCH_SIZE = 64;

    private const string ATTRIBUTES =
      FileAttribute.STANDARD_TYPE + ","
      + FileAttribute.STANDARD_NAME + ","
      + FileAttribute.STANDARD_DISPLAY_NAME + ","
      + FileAttribute.STANDARD_ICON + ","
      + FileAttribute.STANDARD_IS_HIDDEN;

    /** A sorted batch of entries that is ready to be shown. */
    public signal void batch_loaded (Gee.ArrayList<ShelfEntry> entries);

    /** The folder could not be read (permissions, disconnected drive, ...). */
    public signal void load_failed (string message);

    /**
     * The enumeration finished. {@code truncated} is true when the folder held
     * more entries than {@link MAX_ENTRIES}.
     */
    public signal void load_finished (bool truncated);

    private Cancellable? cancellable = null;
    private uint generation = 0;

    /** Cancels any in-flight enumeration. */
    public void cancel () {
      generation++;
      if (cancellable != null) {
        cancellable.cancel ();
        cancellable = null;
      }
    }

    /**
     * Starts enumerating {@code folder}, cancelling any previous request.
     *
     * @param folder the folder to enumerate
     * @param show_hidden whether dot-files and hidden entries are included
     */
    public void load (File folder, bool show_hidden) {
      cancel ();

      generation++;
      var c = new Cancellable ();
      cancellable = c;

      do_load.begin (folder, show_hidden, generation, c);
    }

    private async void do_load (File folder, bool show_hidden, uint my_generation, Cancellable c) {
      var collected = new Gee.ArrayList<ShelfEntry> ();
      bool truncated = false;

      try {
        var enumerator = yield folder.enumerate_children_async (
          ATTRIBUTES,
          FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
          Priority.DEFAULT,
          c
        );

        while (!truncated) {
          var infos = yield enumerator.next_files_async (ENUM_BATCH_SIZE, Priority.DEFAULT, c);
          if (infos == null || infos.length () == 0)
            break;

          foreach (var info in infos) {
            if (c.is_cancelled () || my_generation != generation)
              return;

            if (!show_hidden && info.get_is_hidden ())
              continue;

            var entry = new ShelfEntry (folder.get_child (info.get_name ()));
            entry.apply_info (info);
            collected.add (entry);

            if (collected.size >= MAX_ENTRIES) {
              truncated = true;
              break;
            }
          }
        }

        yield enumerator.close_async (Priority.DEFAULT, c);
      } catch (Error e) {
        if (c.is_cancelled () || my_generation != generation)
          return;

        load_failed (e.message);
        load_finished (false);
        return;
      }

      if (c.is_cancelled () || my_generation != generation)
        return;

      collected.sort ((a, b) => {
        if (a.is_directory != b.is_directory)
          return a.is_directory ? -1 : 1;
        return a.display_name.collate (b.display_name);
      });

      var batch = new Gee.ArrayList<ShelfEntry> ();
      foreach (var entry in collected) {
        if (my_generation != generation)
          return;

        batch.add (entry);
        if (batch.size >= EMIT_BATCH_SIZE) {
          batch_loaded (batch);
          batch = new Gee.ArrayList<ShelfEntry> ();
        }
      }

      if (batch.size > 0)
        batch_loaded (batch);

      if (my_generation == generation)
        load_finished (truncated);
    }
  }
}
