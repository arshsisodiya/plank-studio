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
   * The floating Shelf panel.
   *
   * This is a standalone popup window (like the Clock docklet's calendar)
   * rather than a {@link Gtk.Popover} so it can be moved next to the dock on
   * any edge and stay inside the monitor bounds. It shows the persistent root
   * collection and can drill into folders without ever touching the original
   * files.
   */
  public class ShelfPanel : Gtk.Window {
    private const int PANEL_WIDTH = 340;
    private const int WINDOW_MARGIN = 16;
    private const int SCREEN_MARGIN = 4;
    private const int ARROW_GAP = 4;
    private const double ARROW_SIZE = 8.0;
    private const double ARROW_BASE = 16.0;
    private const double CORNER_RADIUS = 16.0;
    private const uint ANIM_DURATION = 160U;
    private const uint FOCUS_CLOSE_DELAY = 140U;
    private const uint STATUS_CLEAR_DELAY = 3000U;
    private const int MAX_CONTENT_HEIGHT = 380;
    private const int MIN_PANEL_WIDTH = 260;
    private const int MIN_PANEL_HEIGHT = 180;
    private const int RESIZE_EDGE_MARGIN = 14;

    private const string SHELF_ICON =
      "resource://" + G_RESOURCE_PATH + "/icons/shelf.svg";
    private const string SHELF_BLUE_ICON =
      "resource://" + G_RESOURCE_PATH + "/icons/shelf-blue.svg";

    private const string VALIDATE_ATTRIBUTES =
      FileAttribute.STANDARD_TYPE + ","
      + FileAttribute.STANDARD_NAME + ","
      + FileAttribute.STANDARD_DISPLAY_NAME + ","
      + FileAttribute.STANDARD_ICON + ","
      + FileAttribute.STANDARD_IS_HIDDEN;

    /** The panel finished closing. */
    public signal void closed ();

    /** The user toggled the pin state. */
    public signal void pin_toggled (bool pinned);

    private ShelfDirectoryLoader loader;
    private ShelfPath nav_path;
    private ShelfItemView item_view;

    private Gtk.Revealer revealer;
    private Gtk.Overlay overlay;
    private Gtk.Box panel_box;
    private Gtk.Box drop_indicator;
    private Gtk.Stack content_stack;

    private Gtk.Box empty_box;
    private Gtk.Label empty_title;
    private Gtk.Label empty_subtitle;
    private Gtk.Image empty_icon;
    private Gtk.Label error_title;
    private Gtk.Label error_detail;
    private Gtk.Image error_icon;
    private Gtk.Spinner spinner;

    private Gtk.Image header_icon;
    private Gtk.Label title_label;
    private Gtk.Label count_label;
    private Gtk.Box folder_actions_box;
    private Gtk.Button back_button;
    private Gtk.Box nav_box;
    private Gtk.Box breadcrumb_box;
    private Gtk.Label status_label;
    private Gtk.Button clear_button;
    private Gtk.Button open_folder_button;
    private Gtk.ToggleButton hidden_button;
    private Gtk.ToggleButton pin_button;
    private Gtk.Button view_button;
    private Gtk.Button edit_size_button;
    private Gtk.Button size_mode_button;
    private Gtk.Box resize_banner;
    private Gtk.Label resize_dim_label;

    private bool resizing = false;
    private bool is_dragging_resize = false;
    private Gdk.WindowEdge drag_edge = Gdk.WindowEdge.NORTH;
    private int drag_start_root_x = 0;
    private int drag_start_root_y = 0;
    private int drag_start_width = 0;
    private int drag_start_height = 0;

    public bool is_resizing {
      get { return resizing; }
    }

    private Gtk.Menu? active_menu = null;

    private int focus_suppress_count = 0;
    private bool show_hidden = false;
    private bool folder_had_entries = false;
    private bool folder_truncated = false;
    private int folder_entry_count = 0;
    private bool closing = false;
    private bool composited = false;
    private bool detached = false;

    private uint nav_generation = 0;
    private Cancellable? validate_cancellable = null;
    private uint focus_timer_id = 0U;
    private uint status_timer_id = 0U;
    private uint anim_timer_id = 0U;
    private bool anim_hiding = false;
    private uint resize_idle_id = 0U;
    private uint open_idle_id = 0U;

    private bool anchor_valid = false;
    private Gdk.Rectangle anchor_icon = {};
    private Gdk.Rectangle anchor_monitor = {};
    private Gtk.PositionType anchor_position = Gtk.PositionType.BOTTOM;
    private int applied_x = int.MIN;
    private int applied_y = int.MIN;
    private bool applying_position = false;

    public ShelfPanel (ShelfStore store, ShelfPreferences prefs) {
      GLib.Object (store: store, prefs: prefs);
    }

    public ShelfStore store { get; construct; }
    public ShelfPreferences prefs { get; construct; }

    construct {
      loader = new ShelfDirectoryLoader ();
      nav_path = new ShelfPath ();
      show_hidden = prefs.ShowHiddenFiles;

      setup_window ();
      build_ui ();
      connect_signals ();

      store.changed.connect (on_store_changed);

      item_view.set_list_mode (prefs.UseListView);
      item_view.set_propagate_natural_height (!prefs.FixedSize);
      update_view_button ();
      update_count_label ();
      update_footer_buttons ();
    }

    ~ShelfPanel () {
      detach ();
    }

    /**
     * Breaks the signal connections that would otherwise keep this panel, the
     * store and the directory loader alive as a reference cycle after the
     * owning dock item goes away. Safe to call more than once.
     */
    public void detach () {
      if (detached)
        return;

      detached = true;

      cancel_async ();
      cancel_animations ();
      cancel_focus_timer ();
      cancel_menu ();

      store.changed.disconnect (on_store_changed);

      loader.batch_loaded.disconnect (on_batch_loaded);
      loader.load_failed.disconnect (on_load_failed);
      loader.load_finished.disconnect (on_load_finished);
    }

    private void setup_window () {
      title = _("Shelf");
      set_decorated (false);
      set_resizable (false);
      set_skip_taskbar_hint (true);
      set_skip_pager_hint (true);
      set_keep_above (true);
      set_accept_focus (true);
      set_focus_on_map (true);
      set_type_hint (Gdk.WindowTypeHint.UTILITY);
      set_role ("shelf");

      add_events (
        Gdk.EventMask.POINTER_MOTION_MASK
        | Gdk.EventMask.BUTTON_PRESS_MASK
        | Gdk.EventMask.BUTTON_RELEASE_MASK
      );

      int def_w = prefs.FixedSize ? prefs.FixedWidth : PANEL_WIDTH;
      int def_h = prefs.FixedSize ? prefs.FixedHeight : 260;
      set_default_size (def_w + 2 * WINDOW_MARGIN, def_h + 2 * WINDOW_MARGIN);

      get_style_context ().add_class ("shelf-window");

      unowned Gdk.Screen? screen = get_screen ();
      if (screen != null) {
        ShelfUtils.ensure_css (screen);
        composited = screen.is_composited ();
      }

      if (composited) {
        var visual = screen.get_rgba_visual ();
        if (visual != null) {
          set_visual (visual);
          set_app_paintable (true);
        }
      }

      destroy.connect (() => {
        detach ();
      });
    }

    public override bool draw (Cairo.Context cr) {
      if (composited) {
        cr.save ();
        cr.set_operator (Cairo.Operator.CLEAR);
        cr.paint ();
        cr.restore ();
      }

      draw_bubble_frame (cr);

      return base.draw (cr);
    }

    private void create_bubble_path (
      Cairo.Context cr,
      double x, double y, double w, double h,
      double r,
      Gtk.PositionType pos,
      double arrow_cx, double arrow_cy,
      double arrow_w, double arrow_h
    ) {
      double half_w = arrow_w / 2.0;

      cr.move_to (x + r, y);

      if (pos == Gtk.PositionType.TOP) {
        double ax = double.max (x + r + half_w, double.min (x + w - r - half_w, arrow_cx));
        cr.line_to (ax - half_w, y);
        cr.line_to (ax, y - arrow_h);
        cr.line_to (ax + half_w, y);
      }
      cr.line_to (x + w - r, y);
      cr.arc (x + w - r, y + r, r, -Math.PI / 2.0, 0.0);

      if (pos == Gtk.PositionType.RIGHT) {
        double ay = double.max (y + r + half_w, double.min (y + h - r - half_w, arrow_cy));
        cr.line_to (x + w, ay - half_w);
        cr.line_to (x + w + arrow_h, ay);
        cr.line_to (x + w, ay + half_w);
      }
      cr.line_to (x + w, y + h - r);
      cr.arc (x + w - r, y + h - r, r, 0.0, Math.PI / 2.0);

      if (pos == Gtk.PositionType.BOTTOM) {
        double ax = double.max (x + r + half_w, double.min (x + w - r - half_w, arrow_cx));
        cr.line_to (ax + half_w, y + h);
        cr.line_to (ax, y + h + arrow_h);
        cr.line_to (ax - half_w, y + h);
      }
      cr.line_to (x + r, y + h);
      cr.arc (x + r, y + h - r, r, Math.PI / 2.0, Math.PI);

      if (pos == Gtk.PositionType.LEFT) {
        double ay = double.max (y + r + half_w, double.min (y + h - r - half_w, arrow_cy));
        cr.line_to (x, ay + half_w);
        cr.line_to (x - arrow_h, ay);
        cr.line_to (x, ay - half_w);
      }
      cr.line_to (x, y + r);
      cr.arc (x + r, y + r, r, Math.PI, 1.5 * Math.PI);

      cr.close_path ();
    }

    private void draw_bubble_frame (Cairo.Context cr) {
      Gtk.Allocation alloc;
      panel_box.get_allocation (out alloc);
      if (alloc.width <= 0 || alloc.height <= 0)
        return;

      double x = alloc.x;
      double y = alloc.y;
      double w = alloc.width;
      double h = alloc.height;

      double arrow_cx = x + w / 2.0;
      double arrow_cy = y + h / 2.0;

      if (anchor_valid) {
        arrow_cx = (anchor_icon.x + anchor_icon.width / 2.0) - applied_x;
        arrow_cy = (anchor_icon.y + anchor_icon.height / 2.0) - applied_y;
      }

      var pos = anchor_valid ? anchor_position : Gtk.PositionType.BOTTOM;

      if (composited) {
        for (int s = 5; s >= 1; s--) {
          cr.save ();
          create_bubble_path (
            cr,
            x - s * 0.6, y - s * 0.4 + s * 0.8,
            w + s * 1.2, h + s * 0.8,
            CORNER_RADIUS + s * 0.5,
            pos, arrow_cx, arrow_cy,
            ARROW_BASE + s, ARROW_SIZE + s * 0.5
          );
          cr.set_source_rgba (0.0, 0.0, 0.0, 0.045);
          cr.fill ();
          cr.restore ();
        }
      }

      cr.save ();
      create_bubble_path (
        cr,
        x, y, w, h,
        CORNER_RADIUS,
        pos, arrow_cx, arrow_cy,
        ARROW_BASE, ARROW_SIZE
      );
      cr.set_source_rgba (0.11, 0.13, 0.16, 0.88);
      cr.fill_preserve ();

      if (resizing) {
        cr.set_source_rgba (0.21, 0.52, 0.89, 0.95);
        double[] dashes = { 6.0, 4.0 };
        cr.set_dash (dashes, 0.0);
        cr.set_line_width (2.0);
        cr.stroke ();
      } else {
        cr.set_source_rgba (1.0, 1.0, 1.0, 0.13);
        cr.set_line_width (1.0);
        cr.stroke ();
      }
      cr.restore ();
    }

    private void build_ui () {
      panel_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
      panel_box.get_style_context ().add_class ("shelf-panel");
      if (prefs.FixedSize)
        panel_box.set_size_request (prefs.FixedWidth, prefs.FixedHeight);
      else
        panel_box.set_size_request (PANEL_WIDTH, -1);
      panel_box.margin = WINDOW_MARGIN;

      panel_box.pack_start (build_header (), false, false, 0);
      panel_box.pack_start (build_resize_banner (), false, false, 0);
      panel_box.pack_start (build_nav (), false, false, 0);
      panel_box.pack_start (build_content (), true, true, 0);
      panel_box.pack_start (build_footer (), false, false, 0);

      drop_indicator = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
      drop_indicator.get_style_context ().add_class ("shelf-drop-indicator");
      drop_indicator.valign = Gtk.Align.FILL;
      drop_indicator.halign = Gtk.Align.FILL;
      drop_indicator.set_no_show_all (true);
      var drop_label = new Gtk.Label (_("Drop to add to Shelf"));
      drop_label.get_style_context ().add_class ("shelf-drop-label");
      drop_label.halign = Gtk.Align.CENTER;
      drop_label.valign = Gtk.Align.CENTER;
      drop_indicator.pack_start (drop_label, true, true, 0);

      overlay = new Gtk.Overlay ();
      overlay.add (panel_box);
      overlay.add_overlay (drop_indicator);
      overlay.set_overlay_pass_through (drop_indicator, true);

      revealer = new Gtk.Revealer ();
      revealer.set_transition_duration (ANIM_DURATION);
      revealer.set_reveal_child (false);
      revealer.add (overlay);

      add (revealer);
    }

    private Gtk.Widget build_header () {
      var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
      header.get_style_context ().add_class ("shelf-header");

      header_icon = new Gtk.Image ();
      header_icon.set_pixel_size (20);
      header_icon.set_from_pixbuf (DrawingService.load_icon (SHELF_BLUE_ICON, 20, 20));
      header_icon.valign = Gtk.Align.CENTER;
      header_box_add_icon (header, header_icon);

      back_button = new Gtk.Button ();
      back_button.get_style_context ().add_class ("shelf-back-button");
      back_button.set_relief (Gtk.ReliefStyle.NONE);
      back_button.set_image (new Gtk.Image.from_icon_name ("go-previous-symbolic", Gtk.IconSize.BUTTON));
      back_button.set_tooltip_text (_("Back"));
      back_button.clicked.connect (go_back);
      back_button.no_show_all = true;
      header.pack_start (back_button, false, false, 0);

      title_label = new Gtk.Label (_("Shelf"));
      title_label.get_style_context ().add_class ("shelf-title");
      title_label.halign = Gtk.Align.START;
      title_label.valign = Gtk.Align.CENTER;
      header.pack_start (title_label, false, false, 0);

      var spacer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
      header.pack_start (spacer, true, true, 0);

      count_label = new Gtk.Label ("");
      count_label.get_style_context ().add_class ("shelf-count");
      count_label.valign = Gtk.Align.CENTER;
      header.pack_start (count_label, false, false, 0);

      folder_actions_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
      folder_actions_box.no_show_all = true;

      var open_folder_ext = make_header_button ("window-new-symbolic", _("Open folder in file manager"));
      open_folder_ext.clicked.connect (open_current_folder);
      folder_actions_box.pack_start (open_folder_ext, false, false, 0);

      view_button = make_header_button ("view-list-symbolic", _("Toggle list view"));
      folder_actions_box.pack_start (view_button, false, false, 0);

      hidden_button = new Gtk.ToggleButton ();
      style_header_button (hidden_button);
      hidden_button.set_image (new Gtk.Image.from_icon_name ("view-conceal-symbolic", Gtk.IconSize.BUTTON));
      hidden_button.set_tooltip_text (_("Show hidden files"));
      hidden_button.active = show_hidden;
      folder_actions_box.pack_start (hidden_button, false, false, 0);

      pin_button = new Gtk.ToggleButton ();
      style_header_button (pin_button);
      pin_button.set_image (new Gtk.Image.from_icon_name ("view-pin-symbolic", Gtk.IconSize.BUTTON));
      pin_button.set_tooltip_text (_("Keep the Shelf open"));
      pin_button.active = prefs.Pinned;
      folder_actions_box.pack_start (pin_button, false, false, 0);

      header.pack_start (folder_actions_box, false, false, 0);

      var close_button = make_header_button ("window-close-symbolic", _("Close"));
      close_button.clicked.connect (() => close_panel ());
      header.pack_start (close_button, false, false, 0);

      return header;
    }

    private void header_box_add_icon (Gtk.Box header, Gtk.Widget widget) {
      header.pack_start (widget, false, false, 0);
    }

    private Gtk.Widget build_nav () {
      nav_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
      nav_box.get_style_context ().add_class ("shelf-nav");
      nav_box.no_show_all = true;

      breadcrumb_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
      breadcrumb_box.valign = Gtk.Align.CENTER;
      nav_box.pack_start (breadcrumb_box, true, true, 0);

      return nav_box;
    }

    private Gtk.Widget build_content () {
      content_stack = new Gtk.Stack ();
      content_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
      content_stack.transition_duration = 120;

      item_view = new ShelfItemView ();
      item_view.set_max_content_height (MAX_CONTENT_HEIGHT);
      item_view.get_style_context ().add_class ("shelf-content");
      item_view.entry_activated.connect (on_entry_activated);
      item_view.entry_context_menu.connect (on_entry_context_menu);
      item_view.entry_open_containing.connect (on_entry_open_containing);
      item_view.entry_drag_dropped_out.connect (on_entry_drag_dropped_out);
      content_stack.add_named (item_view, "content");

      content_stack.add_named (build_empty_state (), "empty");
      content_stack.add_named (build_loading_state (), "loading");
      content_stack.add_named (build_error_state (), "error");

      return content_stack;
    }

    private Gtk.Widget build_empty_state () {
      empty_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
      empty_box.get_style_context ().add_class ("shelf-empty-box");
      empty_box.set_size_request (-1, 190);
      empty_box.valign = Gtk.Align.CENTER;
      empty_box.halign = Gtk.Align.FILL;

      empty_icon = new Gtk.Image ();
      empty_icon.set_pixel_size (64);
      empty_icon.set_from_pixbuf (DrawingService.load_icon (SHELF_BLUE_ICON, 64, 64));
      empty_box.pack_start (empty_icon, false, false, 0);

      empty_title = new Gtk.Label (_("Shelf is Empty"));
      empty_title.get_style_context ().add_class ("shelf-empty-title");
      empty_title.justify = Gtk.Justification.CENTER;
      empty_box.pack_start (empty_title, false, false, 0);

      empty_subtitle = new Gtk.Label (_("Drag files here to store them temporarily."));
      empty_subtitle.get_style_context ().add_class ("shelf-empty-subtitle");
      empty_subtitle.justify = Gtk.Justification.CENTER;
      empty_subtitle.set_line_wrap (true);
      empty_subtitle.set_max_width_chars (36);
      empty_box.pack_start (empty_subtitle, false, false, 0);

      return empty_box;
    }

    private Gtk.Widget build_loading_state () {
      var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
      box.valign = Gtk.Align.CENTER;
      box.halign = Gtk.Align.CENTER;
      box.margin_top = 30;
      box.margin_bottom = 30;

      spinner = new Gtk.Spinner ();
      box.pack_start (spinner, false, false, 0);

      var label = new Gtk.Label (_("Loading…"));
      label.get_style_context ().add_class ("shelf-empty-subtitle");
      box.pack_start (label, false, false, 0);

      return box;
    }

    private Gtk.Widget build_error_state () {
      var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
      box.valign = Gtk.Align.CENTER;
      box.halign = Gtk.Align.CENTER;
      box.margin_top = 26;
      box.margin_bottom = 26;

      error_icon = new Gtk.Image.from_icon_name ("dialog-error-symbolic", Gtk.IconSize.DIALOG);
      box.pack_start (error_icon, false, false, 0);

      error_title = new Gtk.Label ("");
      error_title.get_style_context ().add_class ("shelf-empty-title");
      error_title.justify = Gtk.Justification.CENTER;
      box.pack_start (error_title, false, false, 0);

      error_detail = new Gtk.Label ("");
      error_detail.get_style_context ().add_class ("shelf-error-detail");
      error_detail.justify = Gtk.Justification.CENTER;
      error_detail.set_line_wrap (true);
      error_detail.set_max_width_chars (40);
      box.pack_start (error_detail, false, false, 0);

      return box;
    }

    private Gtk.Widget build_footer () {
      var footer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
      footer.get_style_context ().add_class ("shelf-footer");

      clear_button = new Gtk.Button ();
      clear_button.get_style_context ().add_class ("shelf-clear-button");
      clear_button.set_relief (Gtk.ReliefStyle.NONE);
      var clear_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
      var trash_icon = new Gtk.Image.from_icon_name ("user-trash-symbolic", Gtk.IconSize.BUTTON);
      var clear_label = new Gtk.Label (_("Clear All"));
      clear_box.pack_start (trash_icon, false, false, 0);
      clear_box.pack_start (clear_label, false, false, 0);
      clear_button.add (clear_box);
      clear_button.set_tooltip_text (_("Remove all items from the Shelf"));
      clear_button.clicked.connect (clear_all);
      footer.pack_start (clear_button, false, false, 0);

      status_label = new Gtk.Label ("");
      status_label.get_style_context ().add_class ("shelf-status");
      status_label.halign = Gtk.Align.START;
      status_label.ellipsize = Pango.EllipsizeMode.END;
      status_label.no_show_all = true;
      footer.pack_start (status_label, false, false, 0);

      var spacer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
      footer.pack_start (spacer, true, true, 0);

      edit_size_button = new Gtk.Button.with_label (_("Edit Size"));
      style_footer_button (edit_size_button);
      edit_size_button.set_tooltip_text (_("Resize and customize Shelf dimensions"));
      edit_size_button.no_show_all = true;
      edit_size_button.clicked.connect (() => start_resize_mode ());
      footer.pack_start (edit_size_button, false, false, 0);

      size_mode_button = new Gtk.Button ();
      style_footer_button (size_mode_button);
      size_mode_button.get_style_context ().add_class ("shelf-size-button");
      size_mode_button.set_image (new Gtk.Image.from_icon_name ("zoom-fit-best-symbolic", Gtk.IconSize.BUTTON));
      size_mode_button.set_tooltip_text (_("Size Settings"));
      size_mode_button.clicked.connect (show_size_menu);
      footer.pack_start (size_mode_button, false, false, 0);

      open_folder_button = new Gtk.Button.with_label (_("Open Folder"));
      style_footer_button (open_folder_button);
      open_folder_button.set_tooltip_text (_("Open this folder in the file manager"));
      open_folder_button.no_show_all = true;
      open_folder_button.clicked.connect (open_current_folder);
      footer.pack_start (open_folder_button, false, false, 0);

      return footer;
    }

    private Gtk.Widget build_resize_banner () {
      resize_banner = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
      resize_banner.get_style_context ().add_class ("shelf-resize-banner");
      resize_banner.no_show_all = true;

      var icon = new Gtk.Image.from_icon_name ("zoom-fit-best-symbolic", Gtk.IconSize.BUTTON);
      icon.valign = Gtk.Align.CENTER;
      resize_banner.pack_start (icon, false, false, 0);

      var label = new Gtk.Label (_("Drag edges or corners"));
      label.get_style_context ().add_class ("shelf-resize-label");
      label.valign = Gtk.Align.CENTER;
      resize_banner.pack_start (label, false, false, 0);

      resize_dim_label = new Gtk.Label ("");
      resize_dim_label.get_style_context ().add_class ("shelf-resize-dim");
      resize_dim_label.valign = Gtk.Align.CENTER;
      resize_banner.pack_start (resize_dim_label, false, false, 0);

      var spacer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
      resize_banner.pack_start (spacer, true, true, 0);

      var lock_btn = new Gtk.Button.with_label (_("Lock Size"));
      lock_btn.get_style_context ().add_class ("shelf-lock-button");
      lock_btn.set_tooltip_text (_("Lock Shelf dimensions"));
      lock_btn.clicked.connect (() => lock_current_size ());
      resize_banner.pack_start (lock_btn, false, false, 0);

      return resize_banner;
    }

    private Gtk.Button make_header_button (string icon, string tooltip) {
      var button = new Gtk.Button ();
      style_header_button (button);
      button.set_image (new Gtk.Image.from_icon_name (icon, Gtk.IconSize.BUTTON));
      button.set_tooltip_text (tooltip);
      return button;
    }

    private static void style_header_button (Gtk.Button button) {
      button.get_style_context ().add_class ("shelf-header-button");
      button.set_relief (Gtk.ReliefStyle.NONE);
    }

    private static void style_footer_button (Gtk.Button button) {
      button.get_style_context ().add_class ("shelf-footer-button");
      button.set_relief (Gtk.ReliefStyle.NONE);
    }

    private void connect_signals () {
      loader.batch_loaded.connect (on_batch_loaded);
      loader.load_failed.connect (on_load_failed);
      loader.load_finished.connect (on_load_finished);

      focus_out_event.connect (on_focus_out);
      focus_in_event.connect (on_focus_in);
      key_press_event.connect (on_key_press);
      motion_notify_event.connect (on_window_motion_notify);
      button_press_event.connect (on_window_button_press);
      button_release_event.connect (on_window_button_release);
      delete_event.connect ((event) => {
        close_panel ();
        return true;
      });

      size_allocate.connect ((allocation) => {
        apply_position ();
        update_input_shape ();
      });

      view_button.clicked.connect (toggle_view_mode);
      hidden_button.toggled.connect (on_hidden_toggled);
      pin_button.toggled.connect (() => {
        prefs.Pinned = pin_button.active;
        pin_toggled (pin_button.active);
      });

      Gtk.TargetEntry te = { "text/uri-list", 0, 0 };
      Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, { te }, Gdk.DragAction.COPY);
      drag_motion.connect (on_drag_motion);
      drag_leave.connect (on_drag_leave);
      drag_data_received.connect (on_drag_data_received);
    }

    //
    // Public API
    //

    /** Records where the panel should appear relative to the Shelf icon. */
    public void set_anchor (
      Gdk.Rectangle icon_rect,
      Gdk.Rectangle monitor_geo,
      Gtk.PositionType position
    ) {
      anchor_icon = icon_rect;
      anchor_monitor = monitor_geo;
      anchor_position = position;
      anchor_valid = true;
      applied_x = int.MIN;
      applied_y = int.MIN;
    }

    /** Shows the panel at the root collection and plays the open animation. */
    public void open (uint32 event_time) {
      closing = false;
      cancel_animations ();

      revealer.set_reveal_child (false);
      set_opacity (0.0);

      show_root ();

      if (prefs.FixedSize) {
        item_view.set_propagate_natural_height (false);
        int target_w = int.max (MIN_PANEL_WIDTH, prefs.FixedWidth);
        int target_h = int.max (MIN_PANEL_HEIGHT, prefs.FixedHeight);
        panel_box.set_size_request (target_w, target_h);
      } else {
        item_view.set_propagate_natural_height (true);
        panel_box.set_size_request (PANEL_WIDTH, -1);
      }
      update_footer_buttons ();

      show_all ();
      if (resize_banner != null && !resizing)
        resize_banner.hide ();
      update_nav ();
      update_transition_type ();
      queue_window_resize ();

      present_with_time (event_time);

      if (open_idle_id > 0U) {
        GLib.Source.remove (open_idle_id);
        open_idle_id = 0U;
      }

      open_idle_id = GLib.Idle.add (() => {
        open_idle_id = 0U;
        play_open_animation ();
        return false;
      });
    }

    /** Hides the panel and plays the close animation. */
    public void close_panel () {
      if (closing || !visible)
        return;

      if (resizing)
        cancel_resize_mode ();

      closing = true;
      focus_suppress_count = 0;
      cancel_focus_timer ();
      cancel_menu ();
      cancel_async ();

      if (animations_enabled ()) {
        anim_hiding = true;
        revealer.set_reveal_child (false);
        animate_opacity (get_opacity (), 0.0, ANIM_DURATION);
      } else {
        finish_close ();
      }
    }

    public bool is_open {
      get { return visible && !closing; }
    }

    //
    // Root / navigation
    //

    private void show_root () {
      cancel_async ();
      nav_generation++;
      nav_path.reset ();
      update_nav ();

      item_view.set_entries (store.get_entries ());

      if (store.count == 0)
        show_empty (
          _("Shelf is Empty"),
          _("Drag files here to store them temporarily."),
          SHELF_BLUE_ICON
        );
      else
        content_stack.set_visible_child_name ("content");

      update_status_default ();

      validate_cancellable = new Cancellable ();
      validate_root_entries.begin (nav_generation, validate_cancellable);
    }

    private void navigate_to (File folder) {
      nav_path.push (folder);
      update_nav ();
      load_folder (folder);
    }

    private void go_back () {
      if (!nav_path.pop ())
        return;

      if (nav_path.is_root)
        show_root ();
      else {
        update_nav ();
        load_folder (nav_path.current);
      }
    }

    private void go_to_index (int index) {
      nav_path.truncate (index + 1);

      if (nav_path.is_root)
        show_root ();
      else {
        update_nav ();
        load_folder (nav_path.current);
      }
    }

    private void load_folder (File folder) {
      cancel_async ();
      nav_generation++;

      folder_had_entries = false;
      folder_truncated = false;
      folder_entry_count = 0;
      status_label.get_style_context ().remove_class ("shelf-truncated");
      item_view.clear ();

      spinner.start ();
      content_stack.set_visible_child_name ("loading");
      update_status_default ();

      loader.load (folder, show_hidden);
    }

    private void reload_current () {
      if (nav_path.is_root)
        show_root ();
      else
        load_folder (nav_path.current);
    }

    private void update_nav () {
      bool is_root = nav_path.is_root;

      header_icon.visible = is_root;
      back_button.visible = !is_root;
      folder_actions_box.visible = !is_root;
      nav_box.visible = !is_root;
      clear_button.visible = is_root;

      if (is_root) {
        title_label.label = _("Shelf");
        update_count_label ();
        status_label.visible = false;
        open_folder_button.visible = false;
      } else {
        var folder = nav_path.current;
        title_label.label = folder != null ? (folder.get_basename () ?? "") : "";
        count_label.visible = false;
        status_label.visible = true;
        update_open_folder_button ();
      }

      foreach (var child in breadcrumb_box.get_children ())
        child.destroy ();

      if (!is_root) {
        var crumbs = build_crumb_labels ();

        for (int i = 0; i < crumbs.size; i++) {
          if (i > 0) {
            var sep = new Gtk.Label ("›");
            sep.get_style_context ().add_class ("shelf-separator");
            sep.valign = Gtk.Align.CENTER;
            breadcrumb_box.pack_start (sep, false, false, 0);
          }

          bool is_last = i == crumbs.size - 1;
          if (is_last) {
            var label = new Gtk.Label (crumbs[i]);
            label.get_style_context ().add_class ("shelf-crumb");
            label.get_style_context ().add_class ("shelf-crumb-current");
            label.ellipsize = Pango.EllipsizeMode.MIDDLE;
            label.set_max_width_chars (16);
            breadcrumb_box.pack_start (label, false, false, 0);
          } else {
            var button = new Gtk.Button.with_label (crumbs[i]);
            button.get_style_context ().add_class ("shelf-crumb");
            button.set_relief (Gtk.ReliefStyle.NONE);
            int target = i;
            button.clicked.connect (() => go_to_index (target));
            breadcrumb_box.pack_start (button, false, false, 0);
          }
        }

        breadcrumb_box.show_all ();
      }
    }

    /**
     * Builds the breadcrumb names, folding the middle away when the path gets
     * deep so the navigation row never overflows.
     */
    private Gee.ArrayList<string> build_crumb_labels () {
      var names = new Gee.ArrayList<string> ();
      names.add (_("Shelf"));

      var nodes = nav_path.get_nodes ();
      foreach (var node in nodes) {
        var basename = node.get_basename ();
        names.add (basename != null && basename != "" ? basename : (node.get_path () ?? ""));
      }

      if (names.size > 4) {
        var folded = new Gee.ArrayList<string> ();
        folded.add (names[0]);
        folded.add ("…");
        folded.add (names[names.size - 2]);
        folded.add (names[names.size - 1]);
        return folded;
      }

      return names;
    }

    //
    // Entry actions
    //

    private void on_entry_drag_dropped_out (ShelfEntry entry) {
      if (nav_path.is_root) {
        store.remove (entry);
        set_status_transient (_("Removed from Shelf"));
      }
    }

    private void on_entry_activated (ShelfEntry entry) {
      if (entry.is_missing) {
        set_status_transient (_("This item no longer exists"));
        return;
      }

      if (entry.is_directory) {
        navigate_to (entry.file);
        return;
      }

      System.get_default ().open (entry.file);
    }

    private void on_entry_open_containing (ShelfEntry entry) {
      var parent = entry.file.get_parent ();
      if (parent == null) {
        set_status_transient (_("No containing folder"));
        return;
      }

      System.get_default ().open (parent);
    }

    private void on_entry_context_menu (ShelfEntry entry, Gdk.EventButton event) {
      var menu = new Gtk.Menu ();

      var open_item = new Gtk.MenuItem.with_mnemonic (_("_Open"));
      open_item.sensitive = !entry.is_missing;
      open_item.activate.connect (() => on_entry_activated (entry));
      menu.append (open_item);

      var open_with_item = new Gtk.MenuItem.with_mnemonic (_("Open _With…"));
      open_with_item.sensitive = !entry.is_missing;
      open_with_item.activate.connect (() => open_with (entry.file));
      menu.append (open_with_item);

      var containing_item = new Gtk.MenuItem.with_mnemonic (_("Open Containing _Folder"));
      containing_item.activate.connect (() => on_entry_open_containing (entry));
      menu.append (containing_item);

      var copy_item = new Gtk.MenuItem.with_mnemonic (_("_Copy Path"));
      copy_item.activate.connect (() => copy_path (entry));
      menu.append (copy_item);

      menu.append (new Gtk.SeparatorMenuItem ());

      if (nav_path.is_root) {
        var remove_item = new Gtk.MenuItem.with_mnemonic (_("_Remove from Shelf"));
        remove_item.activate.connect (() => {
          store.remove (entry);
          set_status_transient (_("Removed from Shelf"));
        });
        menu.append (remove_item);
      } else {
        var add_item = new Gtk.MenuItem.with_mnemonic (_("_Add to Shelf"));
        add_item.activate.connect (() => {
          var uris = new Gee.ArrayList<string> ();
          uris.add (entry.uri);
          add_uris_with_status (uris);
        });
        menu.append (add_item);
      }

      menu.show_all ();
      show_context_menu (menu, event);
    }

    private void copy_path (ShelfEntry entry) {
      var path_text = entry.file.get_path () ?? entry.uri;

      unowned Gdk.Display? display = Gdk.Display.get_default ();
      if (display == null)
        return;

      var clipboard = Gtk.Clipboard.get_default (display);
      clipboard.set_text (path_text, -1);
      clipboard.store ();
      set_status_transient (_("Path copied"));
    }

    private void open_with (File file) {
      var dialog = new Gtk.AppChooserDialog (this, Gtk.DialogFlags.MODAL, file);
      dialog.title = _("Open With");
      dialog.set_heading (_("Choose an application to open “%s”").printf (file.get_basename () ?? ""));

      push_focus_suppress ();

      dialog.response.connect ((response) => {
        if (response == Gtk.ResponseType.OK) {
          var app = dialog.get_app_info ();
          if (app != null) {
            var uris = new GLib.List<string> ();
            uris.append (file.get_uri ());
            try {
              app.launch_uris (uris, System.get_default ().context);
            } catch (Error e) {
              warning ("Could not launch application: %s", e.message);
            }
          }
        }

        dialog.destroy ();
        pop_focus_suppress ();
      });

      dialog.show ();
    }


    private void add_uris_with_status (Gee.ArrayList<string> uris) {
      int duplicates = 0;
      int rejected = 0;
      int added = store.add_uris (uris, out duplicates, out rejected);

      if (added > 0)
        set_status_transient (ngettext ("Added %d item", "Added %d items", added).printf (added));
      else if (duplicates > 0)
        set_status_transient (_("Already in Shelf"));
      else if (rejected > 0)
        set_status_transient (_("Only local files can be added"));
      else
        set_status_transient (_("Nothing to add"));
    }

    private void clear_all () {
      if (store.count == 0)
        return;

      var dialog = new Gtk.MessageDialog (
        this,
        Gtk.DialogFlags.MODAL,
        Gtk.MessageType.QUESTION,
        Gtk.ButtonsType.NONE,
        "%s",
        _("Remove all items from the Shelf?")
      );
      dialog.secondary_text = _("The original files and folders are not affected.");
      dialog.add_button (_("_Cancel"), Gtk.ResponseType.CANCEL);
      dialog.add_button (_("_Clear All"), Gtk.ResponseType.OK);
      dialog.set_default_response (Gtk.ResponseType.CANCEL);

      push_focus_suppress ();
      var response = dialog.run ();
      if (response == Gtk.ResponseType.OK) {
        store.clear ();
        set_status_transient (_("Shelf cleared"));
      }
      dialog.destroy ();
      pop_focus_suppress ();
    }

    //
    // Store / loader callbacks
    //

    private void on_store_changed () {
      update_count_label ();

      if (visible && nav_path.is_root && !closing)
        show_root ();

      update_footer_buttons ();
      queue_window_resize ();
    }

    private void on_batch_loaded (Gee.ArrayList<ShelfEntry> entries) {
      if (!folder_had_entries) {
        folder_had_entries = true;
        content_stack.set_visible_child_name ("content");
      }

      foreach (var entry in entries) {
        item_view.append_entry (entry);
        folder_entry_count++;
      }

      status_label.label = ShelfUtils.item_count_text (folder_entry_count);
    }

    private void on_load_failed (string message) {
      spinner.stop ();
      show_error (_("Can’t open this folder"), message);
    }

    private void on_load_finished (bool truncated) {
      spinner.stop ();
      folder_truncated = truncated;

      if (!folder_had_entries) {
        var folder = nav_path.current;
        show_empty (
          _("This folder is empty"),
          folder != null ? (folder.get_path () ?? "") : "",
          "folder-symbolic"
        );
      }

      update_folder_status ();
      update_open_folder_button ();
    }

    /**
     * Shows the entry count, or a "showing first N" hint when the folder was
     * capped at {@link ShelfDirectoryLoader.MAX_ENTRIES}.
     */
    private void update_folder_status () {
      if (folder_truncated) {
        status_label.label = _("Showing first %d items").printf (folder_entry_count);
        status_label.get_style_context ().add_class ("shelf-truncated");
      } else {
        status_label.label = ShelfUtils.item_count_text (folder_entry_count);
        status_label.get_style_context ().remove_class ("shelf-truncated");
      }
    }

    private async void validate_root_entries (uint generation, Cancellable cancellable) {
      // Iterate over a snapshot: the user can drop or remove items while the
      // async queries are in flight, which would mutate the live list.
      var snapshot = new Gee.ArrayList<ShelfEntry> ();
      snapshot.add_all (store.get_entries ());

      foreach (var entry in snapshot) {
        if (generation != nav_generation || cancellable.is_cancelled ())
          return;

        try {
          var info = yield entry.file.query_info_async (
            VALIDATE_ATTRIBUTES,
            FileQueryInfoFlags.NONE,
            Priority.DEFAULT,
            cancellable
          );

          if (generation != nav_generation || cancellable.is_cancelled ())
            return;

          entry.apply_info (info);
        } catch (Error e) {
          if (generation != nav_generation || e is IOError.CANCELLED)
            return;

          entry.kind_known = true;
          entry.mark_missing ();
        }

        item_view.refresh_entry (entry);
        store.entry_updated (entry);
      }
    }

    //
    // View state helpers
    //

    private void show_empty (string title, string subtitle, string icon_name) {
      empty_title.label = title;
      empty_subtitle.label = subtitle;
      empty_subtitle.visible = subtitle != "";
      empty_icon.set_from_pixbuf (DrawingService.load_icon (icon_name, 56, 56));
      content_stack.set_visible_child_name ("empty");
      update_open_folder_button ();
    }

    private void show_error (string title, string detail) {
      error_title.label = title;
      error_detail.label = detail;
      error_detail.visible = detail != "";
      content_stack.set_visible_child_name ("error");
      update_open_folder_button ();
    }

    private void update_count_label () {
      count_label.label = ShelfUtils.item_count_text (store.count);
      count_label.visible = nav_path.is_root;
    }

    private void update_open_folder_button () {
      bool show = !nav_path.is_root && content_stack.get_visible_child_name () == "content";
      open_folder_button.visible = show;
    }

    private void update_status_default () {
      if (nav_path.is_root) {
        update_count_label ();
        status_label.label = "";
      } else {
        update_folder_status ();
      }
    }

    private void set_status_transient (string message) {
      status_label.label = message;

      if (status_timer_id > 0U)
        GLib.Source.remove (status_timer_id);

      status_timer_id = GLib.Timeout.add (STATUS_CLEAR_DELAY, () => {
        status_timer_id = 0U;
        if (nav_path.is_root)
          update_status_default ();
        else
          update_folder_status ();
        return false;
      });
    }

    private void update_view_button () {
      var icon = item_view.list_mode ? "view-grid-symbolic" : "view-list-symbolic";
      view_button.set_image (new Gtk.Image.from_icon_name (icon, Gtk.IconSize.BUTTON));
    }

    private void toggle_view_mode () {
      var list = !item_view.list_mode;
      item_view.set_list_mode (list);
      prefs.UseListView = list;
      update_view_button ();
      queue_window_resize ();
    }

    private void on_hidden_toggled () {
      show_hidden = hidden_button.active;
      prefs.ShowHiddenFiles = show_hidden;
      reload_current ();
    }

    private void open_current_folder () {
      var folder = nav_path.current;
      if (folder != null)
        System.get_default ().open (folder);
    }

    //
    // Drag and drop
    //

    private bool on_drag_motion (Gdk.DragContext context, int x, int y, uint time_) {
      if (empty_box != null)
        empty_box.get_style_context ().add_class ("drag-hover");

      if (content_stack.get_visible_child_name () != "empty") {
        if (!drop_indicator.visible)
          drop_indicator.show ();
      }

      Gdk.drag_status (context, Gdk.DragAction.COPY, time_);
      return true;
    }

    private void on_drag_leave (Gdk.DragContext context, uint time_) {
      if (empty_box != null)
        empty_box.get_style_context ().remove_class ("drag-hover");

      drop_indicator.hide ();
    }

    private void on_drag_data_received (
      Gdk.DragContext context,
      int x,
      int y,
      Gtk.SelectionData selection_data,
      uint info,
      uint time_
    ) {
      if (empty_box != null)
        empty_box.get_style_context ().remove_class ("drag-hover");

      drop_indicator.hide ();

      var uris = ShelfUtils.extract_uris (selection_data);
      if (uris.size == 0) {
        Gtk.drag_finish (context, false, false, time_);
        return;
      }

      add_uris_with_status (uris);
      Gtk.drag_finish (context, true, false, time_);
    }

    //
    // Focus / keyboard
    //

    private bool on_focus_out (Gdk.EventFocus event) {
      // Do not auto-close on focus out: picking up files to drag into the Shelf
      // requires clicking into file managers, the desktop, or other windows,
      // which triggers focus-out. The panel stays open until closed explicitly
      // via the close button [✕], toggling the dock icon, or pressing Escape.
      return false;
    }

    private bool on_focus_in (Gdk.EventFocus event) {
      cancel_focus_timer ();
      return false;
    }

    private void cancel_focus_timer () {
      if (focus_timer_id > 0U) {
        GLib.Source.remove (focus_timer_id);
        focus_timer_id = 0U;
      }
    }

    private bool on_key_press (Gdk.EventKey event) {
      if (event.keyval == Gdk.Key.Escape) {
        if (resizing) {
          cancel_resize_mode ();
          return true;
        }
        close_panel ();
        return true;
      }

      if (event.keyval == Gdk.Key.BackSpace && !nav_path.is_root) {
        go_back ();
        return true;
      }

      return false;
    }

    //
    // Menus
    //

    private void show_context_menu (Gtk.Menu menu, Gdk.Event event) {
      cancel_menu ();

      active_menu = menu;
      push_focus_suppress ();

      menu.hide.connect (() => {
        if (active_menu == menu) {
          active_menu = null;
          pop_focus_suppress ();
          GLib.Idle.add (() => {
            menu.destroy ();
            return false;
          });
        }
      });

      menu.popup_at_pointer (event);
    }

    private void cancel_menu () {
      if (active_menu != null) {
        var menu = active_menu;
        // Null it first so the menu's own hide handler becomes a no-op and
        // cannot schedule a second destroy for the same widget.
        active_menu = null;
        pop_focus_suppress ();
        menu.destroy ();
      }
    }

    private void push_focus_suppress () {
      focus_suppress_count++;
    }

    private void pop_focus_suppress () {
      if (focus_suppress_count > 0)
        focus_suppress_count--;
    }

    //
    // Positioning and animation
    //

    private void queue_window_resize () {
      if (resize_idle_id > 0U)
        return;

      resize_idle_id = GLib.Idle.add (() => {
        resize_idle_id = 0U;
        update_window_size ();
        return false;
      });
    }

    private void update_window_size () {
      if (!get_realized () || resizing)
        return;

      int width;
      int height;

      if (prefs.FixedSize) {
        int target_w = int.max (MIN_PANEL_WIDTH, prefs.FixedWidth);
        int target_h = int.max (MIN_PANEL_HEIGHT, prefs.FixedHeight);
        panel_box.set_size_request (target_w, target_h);

        width = target_w + 2 * WINDOW_MARGIN;
        height = target_h + 2 * WINDOW_MARGIN;
      } else {
        panel_box.set_size_request (PANEL_WIDTH, -1);

        Gtk.Requisition min_req;
        Gtk.Requisition nat_req;
        overlay.get_preferred_size (out min_req, out nat_req);

        width = int.max (nat_req.width, PANEL_WIDTH + 2 * WINDOW_MARGIN);
        height = nat_req.height;
      }

      if (width <= 0 || height <= 0)
        return;

      set_size_request (width, height);
      resize (width, height);
      apply_position ();
    }

    private void apply_position () {
      if (!anchor_valid || applying_position)
        return;

      int width, height;
      get_size (out width, out height);
      if (width <= 0 || height <= 0)
        return;

      int tip_offset = WINDOW_MARGIN - (int) ARROW_SIZE;
      int x;
      int y;

      switch (anchor_position) {
      default:
      case Gtk.PositionType.BOTTOM:
        x = anchor_icon.x + (anchor_icon.width - width) / 2;
        y = anchor_icon.y - height + tip_offset - ARROW_GAP;
        break;
      case Gtk.PositionType.TOP:
        x = anchor_icon.x + (anchor_icon.width - width) / 2;
        y = anchor_icon.y + anchor_icon.height - tip_offset + ARROW_GAP;
        break;
      case Gtk.PositionType.LEFT:
        x = anchor_icon.x + anchor_icon.width - tip_offset + ARROW_GAP;
        y = anchor_icon.y + (anchor_icon.height - height) / 2;
        break;
      case Gtk.PositionType.RIGHT:
        x = anchor_icon.x - width + tip_offset - ARROW_GAP;
        y = anchor_icon.y + (anchor_icon.height - height) / 2;
        break;
      }

      x = int.max (
        anchor_monitor.x + SCREEN_MARGIN,
        int.min (anchor_monitor.x + anchor_monitor.width - width - SCREEN_MARGIN, x)
      );
      y = int.max (
        anchor_monitor.y + SCREEN_MARGIN,
        int.min (anchor_monitor.y + anchor_monitor.height - height - SCREEN_MARGIN, y)
      );

      if (x == applied_x && y == applied_y)
        return;

      applied_x = x;
      applied_y = y;

      applying_position = true;
      move (x, y);
      applying_position = false;
      queue_draw ();
    }

    private void update_input_shape () {
      if (!composited)
        return;

      if (resizing) {
        input_shape_combine_region (null);
        return;
      }

      Gtk.Allocation allocation;
      panel_box.get_allocation (out allocation);

      if (allocation.width <= 0 || allocation.height <= 0)
        return;

      var region = new Cairo.Region.rectangle ({
        allocation.x, allocation.y, allocation.width, allocation.height
      });
      input_shape_combine_region (region);
    }

    public void start_resize_mode () {
      if (resizing)
        return;

      resizing = true;
      is_dragging_resize = false;

      item_view.set_propagate_natural_height (false);
      set_resizable (true);

      int cur_w = panel_box.get_allocated_width ();
      int cur_h = panel_box.get_allocated_height ();
      if (cur_w <= 0 || cur_h <= 0) {
        cur_w = prefs.FixedSize ? prefs.FixedWidth : PANEL_WIDTH;
        cur_h = prefs.FixedSize ? prefs.FixedHeight : 260;
      }

      cur_w = int.max (MIN_PANEL_WIDTH, cur_w);
      cur_h = int.max (MIN_PANEL_HEIGHT, cur_h);

      panel_box.set_size_request (cur_w, cur_h);
      set_size_request (MIN_PANEL_WIDTH + 2 * WINDOW_MARGIN, MIN_PANEL_HEIGHT + 2 * WINDOW_MARGIN);
      resize (cur_w + 2 * WINDOW_MARGIN, cur_h + 2 * WINDOW_MARGIN);

      if (resize_dim_label != null)
        resize_dim_label.set_text ("%d × %d".printf (cur_w, cur_h));
      if (resize_banner != null)
        resize_banner.show_all ();

      update_input_shape ();
      update_footer_buttons ();
      queue_draw ();
    }

    public void lock_current_size () {
      resizing = false;
      is_dragging_resize = false;

      int final_w = panel_box.get_allocated_width ();
      int final_h = panel_box.get_allocated_height ();
      if (final_w < MIN_PANEL_WIDTH)
        final_w = MIN_PANEL_WIDTH;
      if (final_h < MIN_PANEL_HEIGHT)
        final_h = MIN_PANEL_HEIGHT;

      prefs.FixedWidth = final_w;
      prefs.FixedHeight = final_h;
      prefs.FixedSize = true;

      set_resizable (false);
      if (resize_banner != null)
        resize_banner.hide ();
      update_input_shape ();

      unowned Gdk.Window? win = get_window ();
      if (win != null)
        win.set_cursor (null);

      panel_box.set_size_request (final_w, final_h);
      set_size_request (final_w + 2 * WINDOW_MARGIN, final_h + 2 * WINDOW_MARGIN);
      resize (final_w + 2 * WINDOW_MARGIN, final_h + 2 * WINDOW_MARGIN);

      update_footer_buttons ();
      set_status_transient (_("Size locked: %d × %d").printf (final_w, final_h));
      queue_draw ();
    }

    public void cancel_resize_mode () {
      if (!resizing)
        return;

      resizing = false;
      is_dragging_resize = false;
      set_resizable (false);
      if (resize_banner != null)
        resize_banner.hide ();
      update_input_shape ();

      unowned Gdk.Window? win = get_window ();
      if (win != null)
        win.set_cursor (null);

      update_footer_buttons ();
      update_window_size ();
      queue_draw ();
    }

    public void set_fixed_size_mode (bool fixed) {
      if (resizing)
        cancel_resize_mode ();

      prefs.FixedSize = fixed;
      item_view.set_propagate_natural_height (!fixed);

      if (!fixed) {
        panel_box.set_size_request (PANEL_WIDTH, -1);
        set_status_transient (_("Dynamic Size enabled"));
      } else {
        int w = int.max (MIN_PANEL_WIDTH, prefs.FixedWidth);
        int h = int.max (MIN_PANEL_HEIGHT, prefs.FixedHeight);
        panel_box.set_size_request (w, h);
        set_status_transient (_("Fixed Size enabled (%d × %d)").printf (w, h));
      }

      update_footer_buttons ();
      queue_window_resize ();
      queue_draw ();
    }

    private void update_footer_buttons () {
      if (edit_size_button != null) {
        edit_size_button.visible = (prefs.FixedSize && !resizing);
      }
      if (size_mode_button != null) {
        if (prefs.FixedSize) {
          size_mode_button.set_tooltip_text (
            _("Size Settings: Fixed (%d × %d)").printf (prefs.FixedWidth, prefs.FixedHeight)
          );
        } else {
          size_mode_button.set_tooltip_text (_("Size Settings: Dynamic"));
        }
      }
    }

    private void track_menu (Gtk.Menu menu) {
      cancel_menu ();
      active_menu = menu;
      push_focus_suppress ();
      menu.hide.connect (() => {
        if (active_menu == menu) {
          active_menu = null;
          pop_focus_suppress ();
          GLib.Idle.add (() => {
            menu.destroy ();
            return false;
          });
        }
      });
    }

    private void show_size_menu () {
      var menu = new Gtk.Menu ();

      var dynamic_item = new Gtk.RadioMenuItem.with_label (null, _("Dynamic Size (Default)"));
      dynamic_item.active = !prefs.FixedSize;
      dynamic_item.toggled.connect (() => {
        if (dynamic_item.active)
          set_fixed_size_mode (false);
      });
      menu.append (dynamic_item);

      var fixed_item = new Gtk.RadioMenuItem.with_label_from_widget (dynamic_item, _("Fixed Size"));
      fixed_item.active = prefs.FixedSize;
      fixed_item.toggled.connect (() => {
        if (fixed_item.active)
          set_fixed_size_mode (true);
      });
      menu.append (fixed_item);

      menu.append (new Gtk.SeparatorMenuItem ());

      var edit_item = new Gtk.MenuItem.with_label (_("Edit Size"));
      edit_item.activate.connect (() => start_resize_mode ());
      menu.append (edit_item);

      if (resizing) {
        var lock_item = new Gtk.MenuItem.with_label (_("Lock Size"));
        lock_item.activate.connect (() => lock_current_size ());
        menu.append (lock_item);
      }

      menu.show_all ();
      track_menu (menu);
      menu.popup_at_widget (size_mode_button, Gdk.Gravity.NORTH_WEST, Gdk.Gravity.SOUTH_WEST, null);
    }

    private void show_panel_context_menu (Gdk.EventButton event) {
      var menu = new Gtk.Menu ();

      var dynamic_item = new Gtk.RadioMenuItem.with_label (null, _("Dynamic Size (Default)"));
      dynamic_item.active = !prefs.FixedSize;
      dynamic_item.toggled.connect (() => {
        if (dynamic_item.active)
          set_fixed_size_mode (false);
      });
      menu.append (dynamic_item);

      var fixed_item = new Gtk.RadioMenuItem.with_label_from_widget (dynamic_item, _("Fixed Size"));
      fixed_item.active = prefs.FixedSize;
      fixed_item.toggled.connect (() => {
        if (fixed_item.active)
          set_fixed_size_mode (true);
      });
      menu.append (fixed_item);

      menu.append (new Gtk.SeparatorMenuItem ());

      var edit_item = new Gtk.MenuItem.with_label (_("Edit Size"));
      edit_item.activate.connect (() => start_resize_mode ());
      menu.append (edit_item);

      if (resizing) {
        var lock_item = new Gtk.MenuItem.with_label (_("Lock Size"));
        lock_item.activate.connect (() => lock_current_size ());
        menu.append (lock_item);
      }

      menu.append (new Gtk.SeparatorMenuItem ());

      var clear_item = new Gtk.MenuItem.with_label (_("Clear All"));
      clear_item.sensitive = store.count > 0;
      clear_item.activate.connect (clear_all);
      menu.append (clear_item);

      menu.show_all ();
      show_context_menu (menu, event);
    }

    private bool get_edge_at (int px, int py, out Gdk.WindowEdge edge) {
      edge = Gdk.WindowEdge.NORTH;

      Gtk.Allocation alloc;
      panel_box.get_allocation (out alloc);
      if (alloc.width <= 0 || alloc.height <= 0)
        return false;

      int left = alloc.x;
      int right = alloc.x + alloc.width;
      int top = alloc.y;
      int bottom = alloc.y + alloc.height;

      if (px < left - RESIZE_EDGE_MARGIN || px > right + RESIZE_EDGE_MARGIN ||
          py < top - RESIZE_EDGE_MARGIN || py > bottom + RESIZE_EDGE_MARGIN)
        return false;

      bool near_left = ((px - left).abs () <= RESIZE_EDGE_MARGIN);
      bool near_right = ((px - right).abs () <= RESIZE_EDGE_MARGIN);
      bool near_top = ((py - top).abs () <= RESIZE_EDGE_MARGIN);
      bool near_bottom = ((py - bottom).abs () <= RESIZE_EDGE_MARGIN);

      if (near_top && near_left)
        edge = Gdk.WindowEdge.NORTH_WEST;
      else if (near_top && near_right)
        edge = Gdk.WindowEdge.NORTH_EAST;
      else if (near_bottom && near_left)
        edge = Gdk.WindowEdge.SOUTH_WEST;
      else if (near_bottom && near_right)
        edge = Gdk.WindowEdge.SOUTH_EAST;
      else if (near_top)
        edge = Gdk.WindowEdge.NORTH;
      else if (near_bottom)
        edge = Gdk.WindowEdge.SOUTH;
      else if (near_left)
        edge = Gdk.WindowEdge.WEST;
      else if (near_right)
        edge = Gdk.WindowEdge.EAST;
      else
        return false;

      return true;
    }

    private bool on_window_motion_notify (Gdk.EventMotion event) {
      int win_x, win_y;
      get_position (out win_x, out win_y);
      int px = (int) event.x_root - win_x;
      int py = (int) event.y_root - win_y;

      if (is_dragging_resize) {
        int dx = (int) event.x_root - drag_start_root_x;
        int dy = (int) event.y_root - drag_start_root_y;

        int new_w = drag_start_width;
        int new_h = drag_start_height;

        switch (drag_edge) {
        case Gdk.WindowEdge.EAST:
          new_w = drag_start_width + 2 * dx;
          break;
        case Gdk.WindowEdge.WEST:
          new_w = drag_start_width - 2 * dx;
          break;
        case Gdk.WindowEdge.NORTH:
          if (anchor_position == Gtk.PositionType.BOTTOM)
            new_h = drag_start_height - dy;
          else if (anchor_position == Gtk.PositionType.TOP)
            new_h = drag_start_height - dy;
          else
            new_h = drag_start_height - 2 * dy;
          break;
        case Gdk.WindowEdge.SOUTH:
          if (anchor_position == Gtk.PositionType.TOP)
            new_h = drag_start_height + dy;
          else if (anchor_position == Gtk.PositionType.BOTTOM)
            new_h = drag_start_height + dy;
          else
            new_h = drag_start_height + 2 * dy;
          break;
        case Gdk.WindowEdge.NORTH_EAST:
          new_w = drag_start_width + 2 * dx;
          if (anchor_position == Gtk.PositionType.BOTTOM)
            new_h = drag_start_height - dy;
          else
            new_h = drag_start_height - 2 * dy;
          break;
        case Gdk.WindowEdge.NORTH_WEST:
          new_w = drag_start_width - 2 * dx;
          if (anchor_position == Gtk.PositionType.BOTTOM)
            new_h = drag_start_height - dy;
          else
            new_h = drag_start_height - 2 * dy;
          break;
        case Gdk.WindowEdge.SOUTH_EAST:
          new_w = drag_start_width + 2 * dx;
          if (anchor_position == Gtk.PositionType.TOP)
            new_h = drag_start_height + dy;
          else
            new_h = drag_start_height + dy;
          break;
        case Gdk.WindowEdge.SOUTH_WEST:
          new_w = drag_start_width - 2 * dx;
          if (anchor_position == Gtk.PositionType.TOP)
            new_h = drag_start_height + dy;
          else
            new_h = drag_start_height + dy;
          break;
        }

        int max_w = (anchor_monitor.width > 0) ? anchor_monitor.width - 40 : 1200;
        int max_h = (anchor_monitor.height > 0) ? anchor_monitor.height - 80 : 900;

        new_w = int.max (MIN_PANEL_WIDTH, int.min (max_w, new_w));
        new_h = int.max (MIN_PANEL_HEIGHT, int.min (max_h, new_h));

        panel_box.set_size_request (new_w, new_h);
        int win_w = new_w + 2 * WINDOW_MARGIN;
        int win_h = new_h + 2 * WINDOW_MARGIN;

        set_size_request (MIN_PANEL_WIDTH + 2 * WINDOW_MARGIN, MIN_PANEL_HEIGHT + 2 * WINDOW_MARGIN);
        resize (win_w, win_h);
        apply_position ();

        if (resize_dim_label != null)
          resize_dim_label.set_text ("%d × %d".printf (new_w, new_h));

        queue_draw ();
        return true;
      }

      if (resizing) {
        Gdk.WindowEdge edge;
        unowned Gdk.Window? win = get_window ();
        if (win != null) {
          if (get_edge_at (px, py, out edge)) {
            var display = win.get_display ();
            Gdk.CursorType ctype = Gdk.CursorType.ARROW;
            switch (edge) {
            case Gdk.WindowEdge.NORTH_WEST:
              ctype = Gdk.CursorType.TOP_LEFT_CORNER;
              break;
            case Gdk.WindowEdge.NORTH_EAST:
              ctype = Gdk.CursorType.TOP_RIGHT_CORNER;
              break;
            case Gdk.WindowEdge.SOUTH_WEST:
              ctype = Gdk.CursorType.BOTTOM_LEFT_CORNER;
              break;
            case Gdk.WindowEdge.SOUTH_EAST:
              ctype = Gdk.CursorType.BOTTOM_RIGHT_CORNER;
              break;
            case Gdk.WindowEdge.NORTH:
              ctype = Gdk.CursorType.TOP_SIDE;
              break;
            case Gdk.WindowEdge.SOUTH:
              ctype = Gdk.CursorType.BOTTOM_SIDE;
              break;
            case Gdk.WindowEdge.WEST:
              ctype = Gdk.CursorType.LEFT_SIDE;
              break;
            case Gdk.WindowEdge.EAST:
              ctype = Gdk.CursorType.RIGHT_SIDE;
              break;
            }
            win.set_cursor (new Gdk.Cursor.for_display (display, ctype));
          } else {
            win.set_cursor (null);
          }
        }
      }

      return false;
    }

    private bool on_window_button_press (Gdk.EventButton event) {
      int win_x, win_y;
      get_position (out win_x, out win_y);
      int px = (int) event.x_root - win_x;
      int py = (int) event.y_root - win_y;

      if (event.button == 1) {
        if (resizing) {
          Gdk.WindowEdge edge;
          if (get_edge_at (px, py, out edge)) {
            is_dragging_resize = true;
            drag_edge = edge;
            drag_start_root_x = (int) event.x_root;
            drag_start_root_y = (int) event.y_root;
            drag_start_width = panel_box.get_allocated_width ();
            drag_start_height = panel_box.get_allocated_height ();
            return true;
          }
        }
      } else if (event.button == 3) {
        show_panel_context_menu (event);
        return true;
      }

      return false;
    }

    private bool on_window_button_release (Gdk.EventButton event) {
      if (is_dragging_resize) {
        is_dragging_resize = false;
        return true;
      }
      return false;
    }

    private void update_transition_type () {
      Gtk.RevealerTransitionType transition;

      switch (anchor_position) {
      default:
      case Gtk.PositionType.BOTTOM:
        transition = Gtk.RevealerTransitionType.SLIDE_UP;
        break;
      case Gtk.PositionType.TOP:
        transition = Gtk.RevealerTransitionType.SLIDE_DOWN;
        break;
      case Gtk.PositionType.LEFT:
        transition = Gtk.RevealerTransitionType.SLIDE_RIGHT;
        break;
      case Gtk.PositionType.RIGHT:
        transition = Gtk.RevealerTransitionType.SLIDE_LEFT;
        break;
      }

      revealer.set_transition_type (transition);
    }

    private void play_open_animation () {
      update_transition_type ();

      if (animations_enabled ()) {
        revealer.set_transition_duration (ANIM_DURATION);
        revealer.set_reveal_child (true);
        anim_hiding = false;
        animate_opacity (0.0, 1.0, ANIM_DURATION);
      } else {
        revealer.set_transition_duration (0U);
        revealer.set_reveal_child (true);
        set_opacity (1.0);
      }
    }

    private void finish_close () {
      hide ();
      closing = false;
      closed ();
    }

    private void animate_opacity (double from, double to, uint duration) {
      if (anim_timer_id > 0U) {
        GLib.Source.remove (anim_timer_id);
        anim_timer_id = 0U;
      }

      if (duration == 0U) {
        set_opacity (to);
        if (anim_hiding) {
          anim_hiding = false;
          finish_close ();
        }
        return;
      }

      int64 start = GLib.get_monotonic_time ();
      set_opacity (from);

      // Must use the "owned" variant: the lambda captures locals, so Vala
      // allocates a closure block. The non-owned threads_add_timeout binding
      // would free that block right after the call while the timer still uses
      // it (use-after-free). The *_full variant transfers ownership and keeps
      // the block alive until the source is removed.
      anim_timer_id = Gdk.threads_add_timeout_full (GLib.Priority.DEFAULT, 16U, () => {
        double elapsed = (double) (GLib.get_monotonic_time () - start) / (duration * 1000.0);

        if (elapsed >= 1.0) {
          anim_timer_id = 0U;
          set_opacity (to);

          if (anim_hiding) {
            anim_hiding = false;
            finish_close ();
          }

          return false;
        }

        set_opacity (from + (to - from) * elapsed);
        return true;
      });
    }

    private void cancel_animations () {
      if (anim_timer_id > 0U) {
        GLib.Source.remove (anim_timer_id);
        anim_timer_id = 0U;
      }

      anim_hiding = false;
    }

    private void cancel_async () {
      loader.cancel ();

      if (validate_cancellable != null) {
        validate_cancellable.cancel ();
        validate_cancellable = null;
      }

      if (resize_idle_id > 0U) {
        GLib.Source.remove (resize_idle_id);
        resize_idle_id = 0U;
      }

      if (open_idle_id > 0U) {
        GLib.Source.remove (open_idle_id);
        open_idle_id = 0U;
      }

      if (status_timer_id > 0U) {
        GLib.Source.remove (status_timer_id);
        status_timer_id = 0U;
      }
    }

    private bool animations_enabled () {
      unowned Gtk.Settings? settings = Gtk.Settings.get_default ();
      return settings == null || settings.gtk_enable_animations;
    }
  }
}
