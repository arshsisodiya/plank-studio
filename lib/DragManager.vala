//
// Copyright (C) 2011-2012 Robert Dyer, Rico Tzschichholz
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
   * Handles all of the drag'n'drop events for a dock.
   */
  public class DragManager : GLib.Object {
    public DockController controller { private get; construct; }

    public bool InternalDragActive { get; private set; default = false; }

    public DockItem? DragItem { get; private set; default = null; }

    public bool DragNeedsCheck { get; private set; default = true; }

    bool external_drag_active = false;
    public bool ExternalDragActive {
      get { return external_drag_active; }
      private set {
        if (external_drag_active == value)
          return;
        external_drag_active = value;

        if (!value) {
          drag_known = false;
          drag_data = null;
          drag_data_requested = false;
          DragNeedsCheck = true;
          cached_drop_item = null;
          cached_drop_result = false;
        }
      }
    }

    bool reposition_mode = false;
    public bool RepositionMode {
      get { return reposition_mode; }
      private set {
        if (reposition_mode == value)
          return;
        reposition_mode = value;

        if (reposition_mode)
          disable_drag_to (controller.window);
        else
          enable_drag_to (controller.window);
      }
    }

    Gdk.Window? proxy_window = null;

    bool drag_canceled = false;
    bool drag_known = false;
    bool drag_data_requested = false;
    uint marker = 0U;
    uint drag_hover_timer_id = 0U;
    uint external_drag_idle_id = 0U;

    Gee.ArrayList<string>? drag_data = null;

    // Cache for can_accept_drop results to avoid repeated I/O during drag motion
    unowned DockItem? cached_drop_item = null;
    bool cached_drop_result = false;

    int window_scale_factor = 1;
    ulong drag_item_redraw_handler_id = 0UL;

    /**
     * Creates a new instance of a DragManager, which handles
     * drag'n'drop interactions of a dock.
     *
     * @param controller the {@link DockController} to manage drag'n'drop for
     */
    public DragManager (DockController controller) {
      GLib.Object (controller : controller);
    }

    /**
     * Initializes the drag-manager.  Call after the DockWindow is constructed.
     */
    public void initialize ()
    requires (controller.window != null)
    {
      unowned DockWindow window = controller.window;
      unowned DockPreferences prefs = controller.prefs;

      window.drag_motion.connect (drag_motion);
      window.drag_begin.connect (drag_begin);
      window.drag_data_received.connect (drag_data_received);
      window.drag_data_get.connect (drag_data_get);
      window.drag_drop.connect (drag_drop);
      window.drag_end.connect (drag_end);
      window.drag_leave.connect (drag_leave);
      window.drag_failed.connect (drag_failed);

      prefs.notify["LockItems"].connect (lock_items_changed);

      enable_drag_to (window);
      if (!prefs.LockItems)
        enable_drag_from (window);
    }

    ~DragManager () {
      if (drag_hover_timer_id > 0U) {
        GLib.Source.remove (drag_hover_timer_id);
        drag_hover_timer_id = 0U;
      }

      if (external_drag_idle_id > 0U) {
        GLib.Source.remove (external_drag_idle_id);
        external_drag_idle_id = 0U;
      }

      unowned DockWindow window = controller.window;

      window.drag_motion.disconnect (drag_motion);
      window.drag_begin.disconnect (drag_begin);
      window.drag_data_received.disconnect (drag_data_received);
      window.drag_data_get.disconnect (drag_data_get);
      window.drag_drop.disconnect (drag_drop);
      window.drag_end.disconnect (drag_end);
      window.drag_leave.disconnect (drag_leave);
      window.drag_failed.disconnect (drag_failed);

      controller.prefs.notify["LockItems"].disconnect (lock_items_changed);

      disable_drag_to (window);
      disable_drag_from (window);
    }

    void lock_items_changed () {
      unowned DockWindow window = controller.window;

      if (controller.prefs.LockItems)
        disable_drag_from (window);
      else
        enable_drag_from (window);
    }

    [CCode (instance_pos = -1)]
    void drag_data_get (Gtk.Widget w, Gdk.DragContext context, Gtk.SelectionData selection_data, uint info, uint time_) {
      if (InternalDragActive && DragItem != null) {
        string uri = "%s\r\n".printf (DragItem.as_uri ());
        selection_data.set (selection_data.get_target (), 8, (uchar[]) uri.to_utf8 ());
      }
    }

    /**
     * Whether the current dragged-data is accepted by the given dock-item.
     * Results are cached per item to avoid repeated I/O during drag motion.
     *
     * @param item the dock-item
     */
    public bool drop_is_accepted_by (DockItem item) {
      if (drag_data == null)
        return false;

      // Return cached result if same item
      if (cached_drop_item == item)
        return cached_drop_result;

      // Query and cache
      cached_drop_item = item;
      cached_drop_result = item.can_accept_drop (drag_data);
      return cached_drop_result;
    }

    void set_drag_icon (Gdk.DragContext context, DockItem? item, double opacity = 1.0) {
      if (item == null) {
        Gtk.drag_set_icon_default (context);
        return;
      }

      window_scale_factor = controller.window.get_window ().get_scale_factor ();
      var drag_icon_size = (int) (1.2 * controller.position_manager.ZoomIconSize);
      if (drag_icon_size % 2 == 1)
        drag_icon_size++;
      drag_icon_size *= window_scale_factor;
      var drag_surface = new Surface (drag_icon_size, drag_icon_size);
      drag_surface.Internal.set_device_scale (window_scale_factor, window_scale_factor);

      var item_surface = item.get_surface_copy (drag_icon_size, drag_icon_size, drag_surface);
      unowned Cairo.Context cr = drag_surface.Context;
      if (window_scale_factor > 1) {
        cr.save ();
        cr.scale (1.0 / window_scale_factor, 1.0 / window_scale_factor);
      }
      cr.set_operator (Cairo.Operator.OVER);
      cr.set_source_surface (item_surface.Internal, 0, 0);
      cr.paint_with_alpha (opacity);
      if (window_scale_factor > 1)
        cr.restore ();

      unowned Cairo.Surface surface = drag_surface.Internal;
      surface.set_device_offset (-drag_icon_size / 2.0, -drag_icon_size / 2.0);
      Gtk.drag_set_icon_surface (context, surface);
    }

    [CCode (instance_pos = -1)]
    void drag_begin (Gtk.Widget w, Gdk.DragContext context) {
      unowned DockWindow window = controller.window;

      window.notify["HoveredItem"].connect (hovered_item_changed);

      InternalDragActive = true;
      drag_canceled = false;

      if (proxy_window != null) {
        enable_drag_to (window);
        proxy_window = null;
      }

      DragItem = window.HoveredItem;

      if (RepositionMode)
        DragItem = null;

      if (DragItem == null) {
        Gdk.drag_abort (context, Gtk.get_current_event_time ());
        return;
      }

      set_drag_icon (context, DragItem, 0.8);
      drag_item_redraw_handler_id = DragItem.needs_redraw.connect (() => {
        set_drag_icon (context, DragItem, 0.8);
      });

      // No explicit seat grab: GTK's drag-and-drop machinery already holds
      // the pointer grab for the whole drag, so an extra grab here always
      // failed with INVALID_TIME anyway
    }

    bool drag_target_supported = false;
    bool external_drag_signals_connected = false;
    int last_drag_x = -1;
    int last_drag_y = -1;
    uint32 last_drag_time = 0U;
    Gdk.DragContext? active_drag_context = null;
    Gdk.DragContext? pending_drop_context = null;
    int pending_drop_x = -1;
    int pending_drop_y = -1;
    uint32 pending_drop_time = 0U;

    void cancel_external_drag_idle () {
      if (external_drag_idle_id > 0U) {
        GLib.Source.remove (external_drag_idle_id);
        external_drag_idle_id = 0U;
      }
    }

    void connect_external_drag_signals () {
      if (external_drag_signals_connected)
        return;

      external_drag_signals_connected = true;
      controller.window.notify["HoveredItem"].connect (hovered_item_changed);
      controller.window.notify["HoveredItemProvider"].connect (hovered_item_changed);
    }

    void disconnect_external_drag_signals () {
      if (!external_drag_signals_connected)
        return;

      external_drag_signals_connected = false;
      if (controller.window != null) {
        controller.window.notify["HoveredItem"].disconnect (hovered_item_changed);
        controller.window.notify["HoveredItemProvider"].disconnect (hovered_item_changed);
      }
    }

    void reset_external_drag_state () {
      if (drag_hover_timer_id > 0U) {
        GLib.Source.remove (drag_hover_timer_id);
        drag_hover_timer_id = 0U;
      }

      disconnect_external_drag_signals ();

      drag_known = false;
      drag_data_requested = false;
      drag_target_supported = false;
      drag_data = null;
      cached_drop_item = null;
      cached_drop_result = false;
      last_drag_x = -1;
      last_drag_y = -1;
      last_drag_time = 0U;
      active_drag_context = null;
      pending_drop_context = null;
      pending_drop_x = -1;
      pending_drop_y = -1;
      pending_drop_time = 0U;
      DragNeedsCheck = true;
    }

    Gdk.DragAction choose_drag_action (Gdk.DragContext context) {
      var actions = context.get_actions ();
      if (Gdk.DragAction.COPY in actions)
        return Gdk.DragAction.COPY;
      if (Gdk.DragAction.MOVE in actions)
        return Gdk.DragAction.MOVE;
      if (Gdk.DragAction.LINK in actions)
        return Gdk.DragAction.LINK;
      if (Gdk.DragAction.PRIVATE in actions)
        return Gdk.DragAction.PRIVATE;
      return Gdk.DragAction.COPY;
    }

    bool can_accept_item_drop (DockItem? item) {
      return (drag_data != null && DragNeedsCheck && item != null && drop_is_accepted_by (item));
    }

    unowned DockItemProvider? resolve_add_provider () {
      if (controller.prefs.LockItems)
        return null;

      unowned DockWindow window = controller.window;
      if (!controller.hide_manager.Hovered && window.HoveredItemProvider == null)
        return null;

      return window.HoveredItemProvider ?? controller.default_provider;
    }

    void update_external_drag_feedback (uint32 time_) {
      if (!ExternalDragActive)
        return;

      unowned DockWindow window = controller.window;
      unowned PositionManager position_manager = controller.position_manager;
      unowned HoverWindow hover = controller.hover;
      unowned DockItem? hovered_item = window.HoveredItem;

      if (!drag_target_supported && !drag_data_requested) {
        hover.hide ();
        if (active_drag_context != null)
          Gdk.drag_status (active_drag_context, 0, time_);
        return;
      }

      if (drag_data == null) {
        hover.hide ();
        if (active_drag_context != null)
          Gdk.drag_status (active_drag_context, choose_drag_action (active_drag_context), time_);
        return;
      }

      if (can_accept_item_drop (hovered_item)) {
        int hx, hy;
        position_manager.get_hover_position (hovered_item, out hx, out hy);
        hover.set_text (hovered_item.get_drop_text ());
        hover.show_at (hx, hy, position_manager.Position);
        if (active_drag_context != null)
          Gdk.drag_status (active_drag_context, choose_drag_action (active_drag_context), time_);
        return;
      }

      unowned DockItemProvider? provider = resolve_add_provider ();
      if (provider != null && provider.can_accept_drop (drag_data)) {
        if (last_drag_x >= 0 && last_drag_y >= 0) {
          int hx = last_drag_x, hy = last_drag_y;
          position_manager.get_hover_position_at (ref hx, ref hy);
          hover.set_text (_("Drop to add to dock"));
          hover.show_at (hx, hy, position_manager.Position);
        }
        if (active_drag_context != null)
          Gdk.drag_status (active_drag_context, choose_drag_action (active_drag_context), time_);
        return;
      }

      hover.hide ();
      if (active_drag_context != null)
        Gdk.drag_status (active_drag_context, 0, time_);
    }

    string[] extract_uris_from_selection (Gtk.SelectionData selection_data) {
      string[] uris = selection_data.get_uris ();
      if (uris.length > 0)
        return uris;

      unowned uint8[] raw = selection_data.get_data_with_length ();
      if (raw.length <= 0)
        return {};

      var nul_terminated = new uint8[raw.length + 1];
      Memory.copy (nul_terminated, raw, raw.length);
      nul_terminated[raw.length] = 0;
      return Uri.list_extract_uris ((string) nul_terminated);
    }

    void complete_drop (Gdk.DragContext context, int x, int y, uint32 time_) {
      disconnect_external_drag_signals ();

      if (drag_hover_timer_id > 0U) {
        GLib.Source.remove (drag_hover_timer_id);
        drag_hover_timer_id = 0U;
      }

      unowned DockWindow window = controller.window;
      unowned HideManager hide_manager = controller.hide_manager;
      controller.renderer.update_local_cursor (x, y);
      hide_manager.update_hovered_with_coords (x, y);
      window.update_hovered (x, y);

      bool accepted = false;
      if (drag_data != null && drag_data.size > 0) {
        unowned DockItem? item = window.HoveredItem;
        if (can_accept_item_drop (item)) {
          accepted = item.accept_drop (drag_data);
        } else {
          unowned DockItemProvider? provider = resolve_add_provider ();
          if (provider != null && provider.can_accept_drop (drag_data))
            accepted = provider.accept_drop (drag_data);
        }
      }

      Gtk.drag_finish (context, accepted, false, time_);

      reset_external_drag_state ();
      ExternalDragActive = false;
      controller.hover.hide ();
      controller.renderer.animated_draw ();
      hide_manager.update_hovered ();
    }

    [CCode (instance_pos = -1)]
    void drag_data_received (Gtk.Widget w, Gdk.DragContext context, int x, int y, Gtk.SelectionData selection_data, uint info, uint time_) {
      if (drag_data_requested) {
        drag_data = new Gee.ArrayList<string> ();
        foreach (unowned string raw_uri in extract_uris_from_selection (selection_data)) {
          var s = raw_uri.strip ();
          if (s == "")
            continue;

          if (s.has_prefix (DOCKLET_URI_PREFIX)) {
            drag_data.add (s);
            continue;
          }

          var uri = File.new_for_uri (s).get_uri ();
          if (uri != null)
            drag_data.add (uri);
        }

        drag_data_requested = false;

        if (drag_data.size == 1) {
          var uri = drag_data[0];
          DragNeedsCheck = !(uri.has_prefix (DOCKLET_URI_PREFIX) || uri.has_suffix (".desktop"));
        } else {
          DragNeedsCheck = true;
        }

        if (pending_drop_context != null) {
          var drop_ctx = pending_drop_context;
          var drop_x = pending_drop_x;
          var drop_y = pending_drop_y;
          var drop_time = pending_drop_time;
          pending_drop_context = null;
          complete_drop (drop_ctx, drop_x, drop_y, drop_time);
          return;
        }

        // Force initial redraw for ExternalDrag to pick up new
        // drag_data for can_accept_drop check
        controller.renderer.animated_draw ();

        // Trigger this manually since we will miss to receive the very first emmit
        // after entering the dock-window
        hovered_item_changed ();
        return;
      }

      if (ExternalDragActive)
        update_external_drag_feedback (time_);
      else
        Gdk.drag_status (context, choose_drag_action (context), time_);
    }

    [CCode (instance_pos = -1)]
    bool drag_drop (Gtk.Widget w, Gdk.DragContext context, int x, int y, uint time_) {
      cancel_external_drag_idle ();

      if (drag_hover_timer_id > 0U) {
        GLib.Source.remove (drag_hover_timer_id);
        drag_hover_timer_id = 0U;
      }

      if (drag_data == null) {
        if (!drag_data_requested) {
          unowned DockWindow window = controller.window;
          Gdk.Atom atom = Gtk.drag_dest_find_target (window, context, Gtk.drag_dest_get_target_list (window));
          if (atom.name () != Gdk.Atom.NONE.name ()) {
            drag_target_supported = true;
            drag_data_requested = true;
            pending_drop_context = context;
            pending_drop_x = x;
            pending_drop_y = y;
            pending_drop_time = time_;
            Gtk.drag_get_data (window, context, atom, time_);
            return true;
          }

          Gtk.drag_finish (context, false, false, time_);
          reset_external_drag_state ();
          ExternalDragActive = false;
          controller.hover.hide ();
          return true;
        }

        pending_drop_context = context;
        pending_drop_x = x;
        pending_drop_y = y;
        pending_drop_time = time_;
        return true;
      }

      complete_drop (context, x, y, time_);
      return true;
    }

    [CCode (instance_pos = -1)]
    void drag_end (Gtk.Widget w, Gdk.DragContext context) {
      unowned HideManager hide_manager = controller.hide_manager;

      if (drag_item_redraw_handler_id > 0UL) {
        if (DragItem != null)
          GLib.SignalHandler.disconnect (DragItem, drag_item_redraw_handler_id);
        drag_item_redraw_handler_id = 0UL;
      }

      if (!drag_canceled && DragItem != null) {
        hide_manager.update_hovered ();
        if (!hide_manager.Hovered) {
          if (DragItem.can_be_removed ()) {
            // Remove from dock
            unowned ApplicationDockItem? app_item = (DragItem as ApplicationDockItem);
            if (app_item == null || !(app_item.is_running () || app_item.has_unity_info ())) {
              DragItem.IsVisible = false;
              DragItem.Container.remove (DragItem);
            }
            DragItem.delete ();

            int x, y;
            context.get_device ().get_position (null, out x, out y);
            PoofWindow.get_default ().show_at (x, y);
          }
        } else if (controller.window.HoveredItem == null) {
          // Dropped somewhere on dock
          // Pin this item if possible/needed, so we assume the user cares
          // about this application when changing its position
          if (controller.prefs.AutoPinning && DragItem is TransientDockItem) {
            unowned DefaultApplicationDockItemProvider? provider = (DragItem.Container as DefaultApplicationDockItemProvider);
            if (provider != null)
              provider.pin_item (DragItem);
          }
        }
      }

      InternalDragActive = false;
      DragItem = null;

      controller.window.notify["HoveredItem"].disconnect (hovered_item_changed);

      controller.hover.hide ();

      // Force last redraw for InternalDrag
      controller.renderer.animated_draw ();

      // Make sure to hide the dock again if needed
      hide_manager.update_hovered ();
    }

    [CCode (instance_pos = -1)]
    void drag_leave (Gtk.Widget w, Gdk.DragContext context, uint time_) {
      if (drag_hover_timer_id > 0U) {
        GLib.Source.remove (drag_hover_timer_id);
        drag_hover_timer_id = 0U;
      }

      controller.hide_manager.update_hovered ();
      drag_known = false;

      if (ExternalDragActive) {
        // Make sure ExternalDragActive gets set to false to reactivate HideManager.
        // This is needed while getting a leave event without followed by a drop.
        // Delay it to preserve functionality in drag_drop.
        cancel_external_drag_idle ();

        external_drag_idle_id = Gdk.threads_add_idle (() => {
          external_drag_idle_id = 0U;

          if (pending_drop_context != null || controller.window == null)
            return false;

          reset_external_drag_state ();
          ExternalDragActive = false;

          controller.hover.hide ();

          // If an item was hovered we need it in drag_drop,
          // so reset HoveredItem here not earlier.
          controller.window.update_hovered (-1, -1);

          // Force last redraw for ExternalDrag
          controller.renderer.animated_draw ();

          // Make sure to hide the dock again if needed
          controller.hide_manager.update_hovered ();

          return false;
        });
      }

      if (DragItem == null)
        return;

      if (!controller.hide_manager.Hovered) {
        controller.window.update_hovered (-1, -1);
        controller.renderer.animated_draw ();
      }
    }

    [CCode (instance_pos = -1)]
    bool drag_failed (Gtk.Widget w, Gdk.DragContext context, Gtk.DragResult result) {
      drag_canceled = result == Gtk.DragResult.USER_CANCELLED;

      return !drag_canceled;
    }

    [CCode (instance_pos = -1)]
    bool drag_motion (Gtk.Widget w, Gdk.DragContext context, int x, int y, uint time_) {
      cancel_external_drag_idle ();

      if (RepositionMode)
        return true;

      if (ExternalDragActive == InternalDragActive)
        ExternalDragActive = !InternalDragActive;

      if (marker != direct_hash (context)) {
        marker = direct_hash (context);
        drag_known = false;
      }

      unowned DockWindow window = controller.window;
      unowned HideManager hide_manager = controller.hide_manager;

      // we own the drag if InternalDragActive is true, lets not be silly
      bool starting_external_drag = (ExternalDragActive && !drag_known);
      if (starting_external_drag) {
        reset_external_drag_state ();
        drag_known = true;
      }

      active_drag_context = context;
      last_drag_x = x;
      last_drag_y = y;
      last_drag_time = time_;

      controller.renderer.update_local_cursor (x, y);
      hide_manager.update_hovered_with_coords (x, y);
      window.update_hovered (x, y);

      if (starting_external_drag) {
        connect_external_drag_signals ();

        Gdk.Atom atom = Gtk.drag_dest_find_target (window, context, Gtk.drag_dest_get_target_list (window));
        if (atom.name () != Gdk.Atom.NONE.name ()) {
          drag_target_supported = true;
          drag_data_requested = true;
          Gtk.drag_get_data (window, context, atom, time_);
        }
      }

      if (ExternalDragActive) {
        update_external_drag_feedback (time_);
      } else {
        Gdk.drag_status (context, Gdk.DragAction.COPY, time_);
      }

      return true;
    }

    void hovered_item_changed () {
      unowned DockItem hovered_item = controller.window.HoveredItem;

      if (InternalDragActive && DragItem != null && hovered_item != null
          && DragItem != hovered_item
          && DragItem.Container == hovered_item.Container) {
        DragItem.Container.move_to (DragItem, hovered_item);
      }

      if (drag_hover_timer_id > 0U) {
        GLib.Source.remove (drag_hover_timer_id);
        drag_hover_timer_id = 0U;
      }

      if (ExternalDragActive) {
        update_external_drag_feedback (last_drag_time);

        if (drag_data != null)
          drag_hover_timer_id = Gdk.threads_add_timeout (1500, () => {
            unowned DockItem item = controller.window.HoveredItem;
            if (item != null)
              item.scrolled (Gdk.ScrollDirection.DOWN, 0, Gtk.get_current_event_time ());
            else
              drag_hover_timer_id = 0U;
            return item != null;
          });
      }
    }

    Gdk.Window? best_proxy_window ()
    {
      var window_stack = controller.window.get_screen ().get_window_stack ();
      window_stack.reverse ();

      foreach (var window in window_stack) {
        int w_x, w_y, w_width, w_height;
        window.get_position (out w_x, out w_y);
        w_width = window.get_width ();
        w_height = window.get_height ();
        Gdk.Rectangle w_geo = { w_x, w_y, w_width, w_height };

        int x, y;
        controller.window.get_display ()
         .get_default_seat ()
         .get_pointer ()
         .get_position (null, out x, out y);

        if (window.is_visible () && w_geo.intersect ({ x, y, 0, 0 }, null))
          return window;
      }

      return null;
    }

    public void ensure_proxy () {
      // having a proxy window here is VERY bad ju-ju
      if (InternalDragActive)
        return;

      if (controller.hide_manager.Hovered) {
        if (proxy_window == null)
          return;
        proxy_window = null;
        enable_drag_to (controller.window);
        return;
      }

      Gdk.ModifierType mod;
      double[] axes = {};
      controller.window.get_display ()
       .get_default_seat ()
       .get_pointer ()
       .get_state (controller.window.get_window (), axes, out mod);

      if ((mod & Gdk.ModifierType.BUTTON1_MASK) == Gdk.ModifierType.BUTTON1_MASK) {
        Gdk.Window bestProxy = best_proxy_window ();
        if (bestProxy != null && proxy_window != bestProxy) {
          proxy_window = bestProxy;
          // No equivalent that supports GTK 3 and is not deprecated.
          Gtk.drag_dest_set_proxy (controller.window, proxy_window, Gdk.DragProtocol.XDND, true);
        }
      }
    }

    void enable_drag_to (DockWindow window) {
      Gtk.TargetEntry te1 = { "text/uri-list", 0, 0 };
      Gtk.TargetEntry te2 = { "text/plank-uri-list", 0, 0 };
      Gtk.drag_dest_set (window, 0, { te1, te2 },
                         Gdk.DragAction.COPY | Gdk.DragAction.MOVE | Gdk.DragAction.LINK | Gdk.DragAction.PRIVATE);
    }

    void disable_drag_to (DockWindow window) {
      Gtk.drag_dest_unset (window);
    }

    void enable_drag_from (DockWindow window) {
      // we dont really want to offer the drag to anything, merely pretend to, so we set a mimetype nothing takes
      Gtk.TargetEntry te = { "text/plank-uri-list", Gtk.TargetFlags.SAME_APP, 0 };
      Gtk.drag_source_set (window, Gdk.ModifierType.BUTTON1_MASK, { te }, Gdk.DragAction.PRIVATE);
    }

    void disable_drag_from (DockWindow window) {
      Gtk.drag_source_unset (window);
    }
  }
}
