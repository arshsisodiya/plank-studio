//
// Copyright (C) 2014 Rico Tzschichholz
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
  [GtkTemplate (ui = "/net/launchpad/plank/ui/preferences.ui")]
  public class PreferencesWindow : Gtk.Window {
    /**
     * The controller for this dock.
     */
    public DockController controller { get; construct set; }

    DockPreferences prefs;

    bool refreshing_display_plugs = false;

    [GtkChild]
    unowned Gtk.ComboBoxText cb_theme;
    [GtkChild]
    unowned Gtk.ComboBoxText cb_hidemode;
    [GtkChild]
    unowned Gtk.ComboBoxText cb_display_plug;
    [GtkChild]
    unowned Gtk.ComboBoxText cb_position;
    [GtkChild]
    unowned Gtk.ComboBoxText cb_area_mode;
    [GtkChild]
    unowned Gtk.ComboBoxText cb_alignment;
    [GtkChild]
    unowned Gtk.ComboBoxText cb_items_alignment;
    [GtkChild]
    unowned Gtk.ComboBoxText cb_stack_direction;

    [GtkChild]
    unowned Gtk.SpinButton sp_hide_delay;
    [GtkChild]
    unowned Gtk.SpinButton sp_unhide_delay;
    [GtkChild]
    unowned Gtk.SpinButton sp_preview_delay;
    [GtkChild]
    unowned Gtk.SpinButton sp_preview_size;
    [GtkChild]
    unowned Gtk.Scale s_offset;
    [GtkChild]
    unowned Gtk.Scale s_active_display_polling_interval;
    [GtkChild]
    unowned Gtk.Scale s_zoom_percent;
    [GtkChild]
    unowned Gtk.Scale s_stack_speed;
    [GtkChild]
    unowned Gtk.Scale s_stack_spacing;
    [GtkChild]
    unowned Gtk.Scale s_icon_corner_radius;

    [GtkChild]
    unowned Gtk.Adjustment adj_hide_delay;
    [GtkChild]
    unowned Gtk.Adjustment adj_unhide_delay;
    [GtkChild]
    unowned Gtk.Adjustment adj_preview_delay;
    [GtkChild]
    unowned Gtk.Adjustment adj_preview_size;
    [GtkChild]
    unowned Gtk.Adjustment adj_iconsize;
    [GtkChild]
    unowned Gtk.Adjustment adj_gapsize;
    [GtkChild]
    unowned Gtk.Adjustment adj_offset;
    [GtkChild]
    unowned Gtk.Adjustment adj_active_display_polling_interval;
    [GtkChild]
    unowned Gtk.Adjustment adj_zoom_percent;
    [GtkChild]
    unowned Gtk.Adjustment adj_stack_speed;
    [GtkChild]
    unowned Gtk.Adjustment adj_stack_spacing;
    [GtkChild]
    unowned Gtk.Adjustment adj_icon_corner_radius;

    [GtkChild]
    unowned Gtk.Switch sw_hide;
    [GtkChild]
    unowned Gtk.Switch sw_primary_display;
    [GtkChild]
    unowned Gtk.Switch sw_active_display;
    [GtkChild]
    unowned Gtk.Switch sw_workspace_only;
    [GtkChild]
    unowned Gtk.Switch sw_show_unpinned;
    [GtkChild]
    unowned Gtk.Switch sw_show_new_applications;
    [GtkChild]
    unowned Gtk.Switch sw_lock_items;
    [GtkChild]
    unowned Gtk.Switch sw_tooltips_enabled;
    [GtkChild]
    unowned Gtk.Switch sw_previews_enabled;
    [GtkChild]
    unowned Gtk.Switch sw_anchor_docklets;
    [GtkChild]
    unowned Gtk.Switch sw_anchor_files;
    [GtkChild]
    unowned Gtk.Switch sw_pressure_reveal;
    [GtkChild]
    unowned Gtk.Switch sw_zoom_enabled;
    [GtkChild]
    unowned Gtk.Switch sw_stack_mode;
    [GtkChild]
    unowned Gtk.Switch sw_round_square_icons;
    [GtkChild]
    unowned Gtk.Switch sw_bring_to_workspace;
    [GtkChild]
    unowned Gtk.Switch sw_show_dock_item;

    [GtkChild]
    unowned Gtk.IconView view_docklets;
    [GtkChild]
    unowned Gtk.Box page_items;

    [GtkChild]
    unowned Gtk.ListBox list_docks;
    [GtkChild]
    unowned Gtk.Button btn_add_dock;
    [GtkChild]
    unowned Gtk.Switch sw_avoid_overlap;
    [GtkChild]
    unowned Gtk.Label l_current_dock;
    [GtkChild]
    unowned Gtk.Label l_current_dock_detail;
    [GtkChild]
    unowned Gtk.MenuButton btn_dock_menu;

    DockManager dock_manager;

    /**
     * The dock whose settings are currently bound to the widgets. Used to
     * avoid rebinding everything when the same dock is shown again.
     */
    DockController? bound_controller;

    Gee.ArrayList<string> sidebar_dock_ids = new Gee.ArrayList<string> ();
    bool refreshing_docks = false;

    Gtk.ListBox? list_items;
    Gtk.Button? btn_add_file;
    Gtk.Button? btn_add_folder;

    DockItemProvider? items_provider;
    bool cleaned_up = false;

    public PreferencesWindow (DockController controller) {
      Object (controller: controller);
    }

    construct
    {
      set_title (_("Plank Preferences"));

      prefs = controller.prefs;
      dock_manager = Factory.main.dock_manager;

      bound_controller = controller;

      init_docks_sidebar ();
      init_dock_menu ();
      init_dock_tab ();
      init_items_tab ();
      init_docklets_tab ();
      connect_signals ();

      notify["controller"].connect (controller_changed);
      destroy.connect (cleanup);

      update_header ();
    }

    void controller_changed () {
      if (cleaned_up || bound_controller == controller)
        return;

      disconnect_signals ();
      unbind_items_provider ();

      prefs = controller.prefs;
      bound_controller = controller;

      init_dock_tab ();
      bind_items_provider ();
      update_header ();
      refresh_docks_list ();
      connect_signals ();
    }

    /**
     * Releases the connections which would otherwise keep this window alive
     * after it has been destroyed.
     */
    void cleanup () {
      if (cleaned_up)
        return;

      cleaned_up = true;

      unbind_items_provider ();

      if (dock_manager != null)
        dock_manager.docks_changed.disconnect (refresh_docks_list);

      disconnect_signals ();
    }

    public override bool key_press_event (Gdk.EventKey event) {
      if (event.keyval == Gdk.Key.Escape) {
        destroy ();
        return Gdk.EVENT_STOP;
      }

      return base.key_press_event (event);
    }

    void prefs_changed (Object o, ParamSpec prop) {
      if (cleaned_up)
        return;

      switch (prop.name) {
      case "Alignment":
        cb_alignment.active_id = ((int) prefs.Alignment).to_string ();
        break;
      case "CurrentWorkspaceOnly":
        sw_workspace_only.set_active (prefs.CurrentWorkspaceOnly);
        break;
      case "BringToCurrentWorkspace":
        sw_bring_to_workspace.set_active (prefs.BringToCurrentWorkspace);
        break;
      case "IconSize":
        adj_iconsize.value = prefs.IconSize;
        break;
      case "GapSize":
        adj_gapsize.value = prefs.GapSize;
        break;
      case "ItemsAlignment":
        cb_items_alignment.active_id = ((int) prefs.ItemsAlignment).to_string ();
        break;
      case "HideMode":
        var hide_enabled = (prefs.HideMode != HideType.NONE);
        sw_hide.set_active (hide_enabled);
        if (hide_enabled)
          cb_hidemode.active_id = ((int) prefs.HideMode).to_string ();
        break;
      case "LockItems":
        sw_lock_items.set_active (prefs.LockItems);
        break;
      case "TooltipsEnabled":
        sw_tooltips_enabled.set_active (prefs.TooltipsEnabled);
        break;
      case "PreviewsEnabled":
        sw_previews_enabled.set_active (prefs.PreviewsEnabled);
        break;
      case "PreviewDelay":
        adj_preview_delay.value = prefs.PreviewDelay;
        break;
      case "PreviewSize":
        adj_preview_size.value = prefs.PreviewSize;
        break;
      case "AnchorDocklets":
        sw_anchor_docklets.set_active (prefs.AnchorDocklets);
        break;
      case "AnchorFiles":
        sw_anchor_files.set_active (prefs.AnchorFiles);
        break;
      case "Monitor":
        var pos = 0;
        foreach (unowned string plug_name in Plank.PositionManager.get_monitor_plug_names (get_screen ())) {
          if (plug_name == prefs.Monitor)
            cb_display_plug.set_active (pos);
          pos++;
        }
        break;
      case "Offset":
        adj_offset.value = prefs.Offset;
        break;
      case "PinnedOnly":
        sw_show_unpinned.set_active (!prefs.PinnedOnly);
        break;
      case "ShowNewApplications":
        sw_show_new_applications.set_active (prefs.ShowNewApplications);
        break;
      case "ShowDockItem":
        sw_show_dock_item.set_active (prefs.ShowDockItem);
        break;
      case "Position":
        cb_position.active_id = ((int) prefs.Position).to_string ();
        update_header ();
        break;
      case "AreaMode":
        cb_area_mode.active_id = ((int) prefs.AreaMode).to_string ();
        break;
      case "PressureReveal":
        sw_pressure_reveal.set_active (prefs.PressureReveal);
        break;
      case "Theme":
        var pos = 0;
        foreach (unowned string theme in Plank.Theme.get_theme_list ()) {
          if (theme == prefs.Theme)
            cb_theme.set_active (pos);
          pos++;
        }
        update_header ();
        break;
      case "DisplayName":
        update_header ();
        break;
      case "HideDelay":
        adj_hide_delay.value = prefs.HideDelay;
        break;
      case "UnhideDelay":
        adj_unhide_delay.value = prefs.UnhideDelay;
        break;
      case "ZoomEnabled":
        sw_zoom_enabled.set_active (prefs.ZoomEnabled);
        s_zoom_percent.sensitive = prefs.ZoomEnabled;
        break;
      case "ZoomPercent":
        adj_zoom_percent.value = prefs.ZoomPercent;
        break;
      case "StackMode":
        sw_stack_mode.set_active (prefs.StackMode);
        set_stack_controls_sensitive (prefs.StackMode);
        break;
      case "StackDirection":
        cb_stack_direction.active_id = ((int) prefs.StackDirection).to_string ();
        break;
      case "StackAnimationSpeed":
        adj_stack_speed.value = prefs.StackAnimationSpeed;
        break;
      case "StackItemSpacing":
        adj_stack_spacing.value = prefs.StackItemSpacing;
        break;
      case "RoundSquareIcons":
        sw_round_square_icons.set_active (prefs.RoundSquareIcons);
        s_icon_corner_radius.sensitive = prefs.RoundSquareIcons;
        break;
      case "IconCornerRadius":
        adj_icon_corner_radius.value = prefs.IconCornerRadius;
        break;
      case "ActiveDisplay":
        sw_active_display.set_active (prefs.ActiveDisplay);
        break;
      case "ActiveDisplayPollingInterval":
        adj_active_display_polling_interval.value = prefs.ActiveDisplayPollingInterval;
        break;
      // Ignored settings
      case "DockItems":
        break;
      default:
        warning ("%s not supported", prop.name);
        break;
      }
    }

    bool try_get_active_int_id (Gtk.ComboBox widget, out int id) {
      unowned string? active_id = widget.get_active_id ();
      if (active_id == null) {
        id = 0;
        return false;
      }

      id = int.parse (active_id);
      return true;
    }

    void theme_changed (Gtk.ComboBox widget) {
      string? active_text = ((Gtk.ComboBoxText) widget).get_active_text ();
      if (active_text != null)
        prefs.Theme = active_text;
    }

    void hidemode_changed (Gtk.ComboBox widget) {
      int id;
      if (try_get_active_int_id (widget, out id))
        prefs.HideMode = (HideType) id;
    }

    void position_changed (Gtk.ComboBox widget) {
      int id;
      if (try_get_active_int_id (widget, out id))
        prefs.Position = (Gtk.PositionType) id;
    }

    void area_mode_changed (Gtk.ComboBox widget) {
      int id;
      if (try_get_active_int_id (widget, out id))
        prefs.AreaMode = (AreaType) id;
    }

    void alignment_changed (Gtk.ComboBox widget) {
      int id;
      if (!try_get_active_int_id (widget, out id))
        return;

      prefs.Alignment = (Gtk.Align) id;
      cb_items_alignment.sensitive = (prefs.Alignment == Gtk.Align.FILL);
      s_offset.sensitive = (prefs.Alignment == Gtk.Align.CENTER);
    }

    void items_alignment_changed (Gtk.ComboBox widget) {
      int id;
      if (try_get_active_int_id (widget, out id))
        prefs.ItemsAlignment = (Gtk.Align) id;
    }

    void hide_toggled (GLib.Object widget, ParamSpec param) {
      if (((Gtk.Switch) widget).get_active ()) {
        prefs.HideMode = HideType.INTELLIGENT;
        cb_hidemode.sensitive = true;
        sp_hide_delay.sensitive = true;
        sp_unhide_delay.sensitive = true;
        sw_pressure_reveal.sensitive = true;
      } else {
        prefs.HideMode = HideType.NONE;
        cb_hidemode.sensitive = false;
        sp_hide_delay.sensitive = false;
        sp_unhide_delay.sensitive = false;
        sw_pressure_reveal.sensitive = false;
      }
    }

    void primary_display_toggled (GLib.Object widget, ParamSpec param) {
      if (((Gtk.Switch) widget).get_active ()) {
        prefs.Monitor = "";
        cb_display_plug.sensitive = false;
        sw_active_display.set_active (false);
        s_active_display_polling_interval.sensitive = false;
      } else {
        string? active_monitor = cb_display_plug.get_active_text ();
        if (active_monitor != null)
          prefs.Monitor = active_monitor;
        if (!sw_active_display.get_active ()) {
          cb_display_plug.sensitive = true;
        }
      }
    }

    void workspace_only_toggled (GLib.Object widget, ParamSpec param) {
      prefs.CurrentWorkspaceOnly = ((Gtk.Switch) widget).get_active ();
    }

    void bring_to_workspace_toggled (GLib.Object widget, ParamSpec param) {
      prefs.BringToCurrentWorkspace = ((Gtk.Switch) widget).get_active ();
    }

    void show_unpinned_toggled (GLib.Object widget, ParamSpec param) {
      prefs.PinnedOnly = !((Gtk.Switch) widget).get_active ();
    }

    void show_new_applications_toggled (GLib.Object widget, ParamSpec param) {
      prefs.ShowNewApplications = ((Gtk.Switch) widget).get_active ();
    }

    void show_dock_item_toggled (GLib.Object widget, ParamSpec param) {
      prefs.ShowDockItem = ((Gtk.Switch) widget).get_active ();
    }

    void lock_items_toggled (GLib.Object widget, ParamSpec param) {
      prefs.LockItems = ((Gtk.Switch) widget).get_active ();
    }

    void tooltips_enabled_toggled (GLib.Object widget, ParamSpec param) {
      prefs.TooltipsEnabled = ((Gtk.Switch) widget).get_active ();
    }

    void previews_enabled_toggled (GLib.Object widget, ParamSpec param) {
      var active = ((Gtk.Switch) widget).get_active ();
      prefs.PreviewsEnabled = active;
      sp_preview_delay.sensitive = active;
      sp_preview_size.sensitive = active;
    }

    void anchor_docklets_toggled (GLib.Object widget, ParamSpec param) {
      prefs.AnchorDocklets = ((Gtk.Switch) widget).get_active ();
    }

    void anchor_files_toggled (GLib.Object widget, ParamSpec param) {
      prefs.AnchorFiles = ((Gtk.Switch) widget).get_active ();
    }

    void pressure_reveal_toggled (GLib.Object widget, ParamSpec param) {
      prefs.PressureReveal = ((Gtk.Switch) widget).get_active ();
    }

    void zoom_enabled_toggled (GLib.Object widget, ParamSpec param) {
      if (((Gtk.Switch) widget).get_active ()) {
        prefs.ZoomEnabled = true;
        s_zoom_percent.sensitive = true;
      } else {
        prefs.ZoomEnabled = false;
        s_zoom_percent.sensitive = false;
      }
    }

    void iconsize_changed (Gtk.Adjustment adj) {
      prefs.IconSize = (int) adj.value;
    }

    void gapsize_changed (Gtk.Adjustment adj) {
      prefs.GapSize = (int) adj.value;
    }

    void offset_changed (Gtk.Adjustment adj) {
      prefs.Offset = (int) adj.value;
    }

    void hide_delay_changed (Gtk.Adjustment adj) {
      prefs.HideDelay = (int) adj.value;
    }

    void unhide_delay_changed (Gtk.Adjustment adj) {
      prefs.UnhideDelay = (int) adj.value;
    }

    void preview_delay_changed (Gtk.Adjustment adj) {
      prefs.PreviewDelay = (uint) adj.value;
    }

    void preview_size_changed (Gtk.Adjustment adj) {
      prefs.PreviewSize = (int) adj.value;
    }

    void zoom_percent_changed (Gtk.Adjustment adj) {
      prefs.ZoomPercent = (int) adj.value;
    }

    void set_stack_controls_sensitive (bool active) {
      cb_stack_direction.sensitive = active;
      s_stack_speed.sensitive = active;
      s_stack_spacing.sensitive = active;
    }

    void stack_mode_toggled (GLib.Object widget, ParamSpec param) {
      var active = ((Gtk.Switch) widget).get_active ();
      prefs.StackMode = active;
      set_stack_controls_sensitive (active);
    }

    void stack_direction_changed (Gtk.ComboBox widget) {
      int id;
      if (try_get_active_int_id (widget, out id))
        prefs.StackDirection = (StackDirection) id;
    }

    void stack_speed_changed (Gtk.Adjustment adj) {
      prefs.StackAnimationSpeed = (int) adj.value;
    }

    void stack_spacing_changed (Gtk.Adjustment adj) {
      prefs.StackItemSpacing = (int) adj.value;
    }

    void round_square_icons_toggled (GLib.Object widget, ParamSpec param) {
      var active = ((Gtk.Switch) widget).get_active ();
      prefs.RoundSquareIcons = active;
      s_icon_corner_radius.sensitive = active;
    }

    void icon_corner_radius_changed (Gtk.Adjustment adj) {
      prefs.IconCornerRadius = (int) adj.value;
    }

    void monitor_changed (Gtk.ComboBox widget) {
      if (refreshing_display_plugs)
        return;

      string? active_text = ((Gtk.ComboBoxText) widget).get_active_text ();
      if (active_text != null)
        prefs.Monitor = active_text;
    }

    void active_display_toggled (GLib.Object widget, ParamSpec param) {
      var active = ((Gtk.Switch) widget).get_active ();
      prefs.ActiveDisplay = active;

      if (active) {
        sw_primary_display.set_active (false);
        string? active_monitor = cb_display_plug.get_active_text ();
        if (active_monitor != null)
          prefs.Monitor = active_monitor;
        cb_display_plug.sensitive = false;
        s_active_display_polling_interval.sensitive = true;
      } else {
        if (!sw_primary_display.get_active ()) {
          cb_display_plug.sensitive = true;
        }
        s_active_display_polling_interval.sensitive = false;
      }
    }

    void active_display_polling_interval_changed (Gtk.Adjustment adj) {
      prefs.ActiveDisplayPollingInterval = (uint) adj.value;
    }

    void refresh_display_plugs () {
      if (refreshing_display_plugs)
        return;

      refreshing_display_plugs = true;

      string current_monitor = prefs.Monitor;
      int selected_pos = -1;

      cb_display_plug.remove_all ();

      var pos = 0;
      foreach (unowned string plug_name in Plank.PositionManager.get_monitor_plug_names (get_screen ())) {
        cb_display_plug.append ("%i".printf (pos), plug_name);
        if (plug_name == current_monitor)
          selected_pos = pos;
        pos++;
      }

      if (selected_pos >= 0) {
        cb_display_plug.set_active (selected_pos);
      } else if (current_monitor == "") {
        cb_display_plug.set_active (0);
      } else {
        cb_display_plug.set_active (0);
        prefs.Monitor = "";
        sw_primary_display.set_active (true);
      }

      bool should_be_sensitive = (prefs.Monitor != "" && !prefs.ActiveDisplay);
      cb_display_plug.sensitive = should_be_sensitive;

      refreshing_display_plugs = false;
    }

    void connect_signals () {
      prefs.notify.connect (prefs_changed);

      unowned Gdk.Screen screen = get_screen ();
      screen.monitors_changed.connect (refresh_display_plugs);

      cb_theme.changed.connect (theme_changed);
      cb_hidemode.changed.connect (hidemode_changed);
      cb_position.changed.connect (position_changed);
      cb_area_mode.changed.connect (area_mode_changed);
      adj_hide_delay.value_changed.connect (hide_delay_changed);
      adj_unhide_delay.value_changed.connect (unhide_delay_changed);
      cb_display_plug.changed.connect (monitor_changed);
      adj_iconsize.value_changed.connect (iconsize_changed);
      adj_gapsize.value_changed.connect (gapsize_changed);
      adj_offset.value_changed.connect (offset_changed);
      adj_zoom_percent.value_changed.connect (zoom_percent_changed);
      sw_hide.notify["active"].connect (hide_toggled);
      sw_primary_display.notify["active"].connect (primary_display_toggled);
      sw_active_display.notify["active"].connect (active_display_toggled);
      adj_active_display_polling_interval.value_changed.connect (active_display_polling_interval_changed);
      sw_workspace_only.notify["active"].connect (workspace_only_toggled);
      sw_bring_to_workspace.notify["active"].connect (bring_to_workspace_toggled);
      sw_show_unpinned.notify["active"].connect (show_unpinned_toggled);
      sw_show_new_applications.notify["active"].connect (show_new_applications_toggled);
      sw_show_dock_item.notify["active"].connect (show_dock_item_toggled);
      sw_lock_items.notify["active"].connect (lock_items_toggled);
      sw_tooltips_enabled.notify["active"].connect (tooltips_enabled_toggled);
      sw_previews_enabled.notify["active"].connect (previews_enabled_toggled);
      adj_preview_delay.value_changed.connect (preview_delay_changed);
      adj_preview_size.value_changed.connect (preview_size_changed);
      sw_anchor_docklets.notify["active"].connect (anchor_docklets_toggled);
      sw_anchor_files.notify["active"].connect (anchor_files_toggled);
      sw_pressure_reveal.notify["active"].connect (pressure_reveal_toggled);
      sw_zoom_enabled.notify["active"].connect (zoom_enabled_toggled);
      sw_stack_mode.notify["active"].connect (stack_mode_toggled);
      cb_stack_direction.changed.connect (stack_direction_changed);
      adj_stack_speed.value_changed.connect (stack_speed_changed);
      adj_stack_spacing.value_changed.connect (stack_spacing_changed);
      sw_round_square_icons.notify["active"].connect (round_square_icons_toggled);
      adj_icon_corner_radius.value_changed.connect (icon_corner_radius_changed);
      cb_alignment.changed.connect (alignment_changed);
      cb_items_alignment.changed.connect (items_alignment_changed);
    }

    void disconnect_signals () {
      prefs.notify.disconnect (prefs_changed);

      unowned Gdk.Screen screen = get_screen ();
      screen.monitors_changed.disconnect (refresh_display_plugs);

      cb_theme.changed.disconnect (theme_changed);
      cb_hidemode.changed.disconnect (hidemode_changed);
      cb_position.changed.disconnect (position_changed);
      cb_area_mode.changed.disconnect (area_mode_changed);
      adj_hide_delay.value_changed.disconnect (hide_delay_changed);
      adj_unhide_delay.value_changed.disconnect (unhide_delay_changed);
      cb_display_plug.changed.disconnect (monitor_changed);
      adj_iconsize.value_changed.disconnect (iconsize_changed);
      adj_gapsize.value_changed.disconnect (gapsize_changed);
      adj_offset.value_changed.disconnect (offset_changed);
      adj_zoom_percent.value_changed.disconnect (zoom_percent_changed);
      sw_hide.notify["active"].disconnect (hide_toggled);
      sw_primary_display.notify["active"].disconnect (primary_display_toggled);
      sw_active_display.notify["active"].disconnect (active_display_toggled);
      adj_active_display_polling_interval.value_changed.disconnect (active_display_polling_interval_changed);
      sw_workspace_only.notify["active"].disconnect (workspace_only_toggled);
      sw_bring_to_workspace.notify["active"].disconnect (bring_to_workspace_toggled);
      sw_show_unpinned.notify["active"].disconnect (show_unpinned_toggled);
      sw_show_new_applications.notify["active"].disconnect (show_new_applications_toggled);
      sw_show_dock_item.notify["active"].disconnect (show_dock_item_toggled);
      sw_lock_items.notify["active"].disconnect (lock_items_toggled);
      sw_tooltips_enabled.notify["active"].disconnect (tooltips_enabled_toggled);
      sw_previews_enabled.notify["active"].disconnect (previews_enabled_toggled);
      adj_preview_delay.value_changed.disconnect (preview_delay_changed);
      adj_preview_size.value_changed.disconnect (preview_size_changed);
      sw_anchor_docklets.notify["active"].disconnect (anchor_docklets_toggled);
      sw_anchor_files.notify["active"].disconnect (anchor_files_toggled);
      sw_pressure_reveal.notify["active"].disconnect (pressure_reveal_toggled);
      sw_zoom_enabled.notify["active"].disconnect (zoom_enabled_toggled);
      sw_stack_mode.notify["active"].disconnect (stack_mode_toggled);
      cb_stack_direction.changed.disconnect (stack_direction_changed);
      adj_stack_speed.value_changed.disconnect (stack_speed_changed);
      adj_stack_spacing.value_changed.disconnect (stack_spacing_changed);
      sw_round_square_icons.notify["active"].disconnect (round_square_icons_toggled);
      adj_icon_corner_radius.value_changed.disconnect (icon_corner_radius_changed);
      cb_alignment.changed.disconnect (alignment_changed);
      cb_items_alignment.changed.disconnect (items_alignment_changed);
    }

    void init_dock_tab () {
      var pos = 0;
      cb_theme.remove_all ();
      foreach (unowned string theme in Plank.Theme.get_theme_list ()) {
        cb_theme.append ("%i".printf (pos), theme);
        if (theme == prefs.Theme)
          cb_theme.set_active (pos);
        pos++;
      }

      cb_hidemode.active_id = ((int) prefs.HideMode).to_string ();
      cb_hidemode.sensitive = (prefs.HideMode != HideType.NONE);
      cb_position.active_id = ((int) prefs.Position).to_string ();
      cb_area_mode.active_id = ((int) prefs.AreaMode).to_string ();
      adj_hide_delay.value = prefs.HideDelay;
      adj_unhide_delay.value = prefs.UnhideDelay;

      refresh_display_plugs ();

      sp_hide_delay.sensitive = (prefs.HideMode != HideType.NONE);
      sp_unhide_delay.sensitive = (prefs.HideMode != HideType.NONE);

      adj_iconsize.value = prefs.IconSize;
      adj_gapsize.value = prefs.GapSize;
      adj_offset.value = prefs.Offset;
      adj_zoom_percent.value = prefs.ZoomPercent;
      s_offset.sensitive = (prefs.Alignment == Gtk.Align.CENTER);
      s_zoom_percent.sensitive = prefs.ZoomEnabled;
      sw_hide.set_active (prefs.HideMode != HideType.NONE);
      sw_primary_display.set_active (prefs.Monitor == "");
      sw_active_display.set_active (prefs.ActiveDisplay);
      adj_active_display_polling_interval.value = prefs.ActiveDisplayPollingInterval;
      if (prefs.ActiveDisplay) {
        cb_display_plug.sensitive = false;
        s_active_display_polling_interval.sensitive = true;
      } else if (prefs.Monitor == "") {
        cb_display_plug.sensitive = false;
        s_active_display_polling_interval.sensitive = false;
      } else {
        cb_display_plug.sensitive = true;
        s_active_display_polling_interval.sensitive = false;
      }
      sw_workspace_only.set_active (prefs.CurrentWorkspaceOnly);
      sw_bring_to_workspace.set_active (prefs.BringToCurrentWorkspace);
      sw_show_unpinned.set_active (!prefs.PinnedOnly);
      sw_show_new_applications.set_active (prefs.ShowNewApplications);
      sw_show_dock_item.set_active (prefs.ShowDockItem);
      sw_lock_items.set_active (prefs.LockItems);
      sw_tooltips_enabled.set_active (prefs.TooltipsEnabled);
      sw_previews_enabled.set_active (prefs.PreviewsEnabled);
      adj_preview_delay.value = prefs.PreviewDelay;
      adj_preview_size.value = prefs.PreviewSize;
      sp_preview_delay.sensitive = prefs.PreviewsEnabled;
      sp_preview_size.sensitive = prefs.PreviewsEnabled;
      sw_anchor_docklets.set_active (prefs.AnchorDocklets);
      sw_anchor_files.set_active (prefs.AnchorFiles);
      sw_pressure_reveal.set_active (prefs.PressureReveal);
      sw_zoom_enabled.set_active (prefs.ZoomEnabled);
      sw_stack_mode.set_active (prefs.StackMode);
      cb_stack_direction.active_id = ((int) prefs.StackDirection).to_string ();
      adj_stack_speed.value = prefs.StackAnimationSpeed;
      adj_stack_spacing.value = prefs.StackItemSpacing;
      set_stack_controls_sensitive (prefs.StackMode);
      sw_round_square_icons.set_active (prefs.RoundSquareIcons);
      adj_icon_corner_radius.value = prefs.IconCornerRadius;
      s_icon_corner_radius.sensitive = prefs.RoundSquareIcons;
      cb_alignment.active_id = ((int) prefs.Alignment).to_string ();
      cb_items_alignment.active_id = ((int) prefs.ItemsAlignment).to_string ();
      cb_items_alignment.sensitive = (prefs.Alignment == Gtk.Align.FILL);
    }

    //
    // Docks sidebar
    //

    void init_docks_sidebar () {
      list_docks.set_activate_on_single_click (true);
      list_docks.row_selected.connect (dock_row_selected);
      btn_add_dock.clicked.connect (add_dock_clicked);

      sw_avoid_overlap.set_active (dock_manager.get_avoid_overlap ());
      sw_avoid_overlap.notify["active"].connect (avoid_overlap_toggled);

      dock_manager.docks_changed.connect (refresh_docks_list);
      refresh_docks_list ();
    }

    void init_dock_menu () {
      var menu = new Gtk.Menu ();

      var rename_item = new Gtk.MenuItem.with_label (_("Rename Dock..."));
      rename_item.activate.connect (() => rename_dock_clicked (controller.name));
      menu.append (rename_item);

      var duplicate_item = new Gtk.MenuItem.with_label (_("Duplicate Dock"));
      duplicate_item.activate.connect (() => duplicate_dock_clicked (controller.name));
      menu.append (duplicate_item);

      menu.append (new Gtk.SeparatorMenuItem ());

      var delete_item = new Gtk.MenuItem.with_label (_("Delete Dock..."));
      delete_item.activate.connect (() => delete_dock_clicked (controller.name));
      menu.append (delete_item);

      menu.show_all ();
      btn_dock_menu.set_popup (menu);
    }

    void avoid_overlap_toggled (GLib.Object widget, ParamSpec prop) {
      if (cleaned_up || sw_avoid_overlap == null || dock_manager == null)
        return;

      dock_manager.set_avoid_overlap (sw_avoid_overlap.get_active ());
    }

    void refresh_docks_list () {
      if (list_docks == null)
        return;

      var selected_id = controller.name;

      refreshing_docks = true;

      Gtk.ListBoxRow? row;
      while ((row = list_docks.get_row_at_index (0)) != null)
        list_docks.remove (row);

      sidebar_dock_ids.clear ();

      Gtk.ListBoxRow? selected_row = null;
      foreach (unowned string id in dock_manager.get_known_docks ()) {
        var dock_row = make_dock_row (id);
        list_docks.add (dock_row);
        sidebar_dock_ids.add (id);
        dock_row.show_all ();

        if (id == selected_id)
          selected_row = dock_row;
      }

      if (selected_row != null)
        list_docks.select_row (selected_row);
      else if (list_docks.get_row_at_index (0) != null)
        list_docks.select_row (list_docks.get_row_at_index (0));

      refreshing_docks = false;
    }

    Gtk.ListBoxRow make_dock_row (string dock_id) {
      var row = new Gtk.ListBoxRow ();
      row.selectable = dock_manager.is_enabled (dock_id);
      row.set_tooltip_text (row.selectable
        ? _("Edit this dock's settings")
        : _("Enable this dock to edit its settings"));

      var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
      box.margin = 8;

      var icon = new Gtk.Image.from_icon_name ("video-display-symbolic", Gtk.IconSize.BUTTON);
      icon.valign = Gtk.Align.CENTER;
      box.pack_start (icon, false, false, 0);

      var labels = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
      labels.hexpand = true;

      var display_name = dock_manager.get_display_name (dock_id);

      var name = new Gtk.Label ("");
      name.set_markup ("<b>%s</b>".printf (GLib.Markup.escape_text (display_name)));
      name.halign = Gtk.Align.START;
      name.set_ellipsize (Pango.EllipsizeMode.END);
      labels.pack_start (name, false, false, 0);

      // Only show the internal id when the user gave the dock a different name
      if (display_name != dock_id) {
        var id_label = new Gtk.Label (dock_id);
        id_label.halign = Gtk.Align.START;
        id_label.set_ellipsize (Pango.EllipsizeMode.END);
        id_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        labels.pack_start (id_label, false, false, 0);
      }

      box.pack_start (labels, true, true, 0);

      var enabled = new Gtk.Switch ();
      enabled.valign = Gtk.Align.CENTER;
      enabled.set_active (dock_manager.is_enabled (dock_id));
      enabled.tooltip_text = _("Show this dock");
      enabled.notify["active"].connect ((o, ps) => dock_enabled_toggled (dock_id, enabled));
      box.pack_end (enabled, false, false, 0);

      row.add (box);
      return row;
    }

    void dock_row_selected (Gtk.ListBoxRow? row) {
      if (refreshing_docks || row == null)
        return;

      var index = row.get_index ();
      if (index < 0 || index >= sidebar_dock_ids.size)
        return;

      var dock_id = sidebar_dock_ids[index];
      if (dock_id == controller.name)
        return;

      select_dock (dock_id);
    }

    void select_dock (string dock_id) {
      var dock = Factory.main.find_dock (dock_id);
      if (dock != null)
        controller = dock;
    }

    void dock_enabled_toggled (string dock_id, Gtk.Switch widget) {
      var wanted = widget.get_active ();
      if (wanted == dock_manager.is_enabled (dock_id))
        return;

      if (!dock_manager.set_enabled (dock_id, wanted)) {
        widget.set_active (dock_manager.is_enabled (dock_id));
        if (!wanted)
          show_message (_("At least one dock has to stay enabled."));
        else
          show_message (_("Could not enable this dock."));
        return;
      }

      if (wanted)
        select_dock (dock_id);
    }

    void add_dock_clicked () {
      var name = prompt_for_name (_("Add Dock"), _("Name for the new dock:"), "");
      if (name == null)
        return;

      var dock_id = dock_manager.create_dock (name);
      if (dock_id == null) {
        show_message (_("Could not add a dock. Plank supports at most %d docks.").printf (DockManager.MAX_DOCKS));
        return;
      }

      select_dock (dock_id);
    }

    void duplicate_dock_clicked (string dock_id) {
      var new_id = dock_manager.duplicate_dock (dock_id);
      if (new_id == null) {
        show_message (_("Could not duplicate this dock. Plank supports at most %d docks.").printf (DockManager.MAX_DOCKS));
        return;
      }

      select_dock (new_id);
    }

    void rename_dock_clicked (string dock_id) {
      var current = dock_manager.get_display_name (dock_id);
      var name = prompt_for_name (_("Rename Dock"), _("Name for this dock:"), current);
      if (name == null)
        return;

      dock_manager.rename_dock (dock_id, name);
      update_header ();
    }

    void delete_dock_clicked (string dock_id) {
      var display_name = dock_manager.get_display_name (dock_id);

      if (!confirm (_("Delete the dock \"%s\"?").printf (display_name),
                    _("Its settings and items will be removed permanently.")))
        return;

      if (!dock_manager.delete_dock (dock_id))
        show_message (_("At least one dock has to remain."));
    }

    void update_header () {
      if (cleaned_up || prefs == null || l_current_dock == null)
        return;

      l_current_dock.set_markup ("<b>%s</b>".printf (GLib.Markup.escape_text (dock_manager.get_display_name (controller.name))));
      l_current_dock_detail.set_text ("%s · %s · %s".printf (controller.name, position_label (prefs.Position), prefs.Theme));
    }

    string position_label (Gtk.PositionType position) {
      switch (position) {
      case Gtk.PositionType.LEFT:
        return _("Left edge");
      case Gtk.PositionType.RIGHT:
        return _("Right edge");
      case Gtk.PositionType.TOP:
        return _("Top edge");
      case Gtk.PositionType.BOTTOM:
      default:
        return _("Bottom edge");
      }
    }

    //
    // Docklets tab
    //

    void init_docklets_tab () {
      var model_docklets = new DockletViewModel ();
      var sorted_docklets = new Gtk.TreeModelSort.with_model (model_docklets);

      Gtk.TargetEntry te = { "text/plank-uri-list", Gtk.TargetFlags.SAME_APP, 0 };
      view_docklets.enable_model_drag_source (Gdk.ModifierType.BUTTON1_MASK, { te }, Gdk.DragAction.PRIVATE);
      view_docklets.set_text_column (DockletViewModel.Column.NAME);
      view_docklets.set_tooltip_column (DockletViewModel.Column.DESCRIPTION);
      view_docklets.set_pixbuf_column (DockletViewModel.Column.PIXBUF);
      view_docklets.drag_begin.connect_after (view_drag_begin);
      view_docklets.item_activated.connect (view_item_activated);

      foreach (var docklet in DockletManager.get_default ().list_docklets ()) {
        var pixbuf = DrawingService.load_icon (docklet.get_icon (), 48, 48);
        model_docklets.add (docklet.get_id (), docklet.get_name (), docklet.get_description (), docklet.get_icon (), pixbuf);
      }

      sorted_docklets.set_sort_column_id (DockletViewModel.Column.NAME, Gtk.SortType.ASCENDING);
      view_docklets.set_model (sorted_docklets);
    }

    //
    // Items tab
    //

    void init_items_tab () {
      if (list_items != null) {
        bind_items_provider ();
        return;
      }

      var hint = new Gtk.Label (_("Items shown on this dock. Drag files or folders here to add them."));
      hint.halign = Gtk.Align.START;
      hint.xalign = 0.0f;
      hint.set_line_wrap (true);
      hint.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
      page_items.pack_start (hint, false, false, 0);

      var scrolled = new Gtk.ScrolledWindow (null, null);
      scrolled.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
      scrolled.set_shadow_type (Gtk.ShadowType.IN);
      scrolled.set_min_content_height (300);

      list_items = new Gtk.ListBox ();
      list_items.set_selection_mode (Gtk.SelectionMode.NONE);
      list_items.set_activate_on_single_click (false);
      scrolled.add (list_items);
      page_items.pack_start (scrolled, true, true, 0);

      Gtk.TargetEntry te = { "text/uri-list", 0, 0 };
      Gtk.drag_dest_set (list_items, 0, { te }, Gdk.DragAction.COPY);
      list_items.drag_data_received.connect (items_drag_data_received);

      var buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
      btn_add_file = new Gtk.Button.with_label (_("Add File"));
      btn_add_file.clicked.connect (() => add_item_clicked (false));
      buttons.pack_start (btn_add_file, false, false, 0);

      btn_add_folder = new Gtk.Button.with_label (_("Add Folder"));
      btn_add_folder.clicked.connect (() => add_item_clicked (true));
      buttons.pack_start (btn_add_folder, false, false, 0);
      page_items.pack_start (buttons, false, false, 0);

      page_items.show_all ();

      bind_items_provider ();
    }

    void bind_items_provider () {
      unbind_items_provider ();

      unowned ApplicationDockItemProvider? provider = controller.default_provider as ApplicationDockItemProvider;
      if (provider != null) {
        items_provider = provider;
        provider.elements_changed.connect (items_provider_changed);
        provider.positions_changed.connect (items_provider_positions_changed);
      }

      refresh_items_list ();
    }

    void unbind_items_provider () {
      if (items_provider == null)
        return;

      items_provider.elements_changed.disconnect (items_provider_changed);
      items_provider.positions_changed.disconnect (items_provider_positions_changed);
      items_provider = null;
    }

    void items_provider_changed (Gee.List<DockElement> added, Gee.List<DockElement> removed) {
      refresh_items_list ();
    }

    void items_provider_positions_changed (Gee.List<unowned DockElement> elements) {
      refresh_items_list ();
    }

    Gee.ArrayList<DockItem> get_pinned_items () {
      var result = new Gee.ArrayList<DockItem> ();

      if (items_provider == null)
        return result;

      foreach (var element in items_provider.Elements) {
        unowned DockItem? item = element as DockItem;
        if (item != null && !(item is TransientDockItem))
          result.add (item);
      }

      return result;
    }

    void refresh_items_list () {
      if (list_items == null)
        return;

      Gtk.ListBoxRow? row;
      while ((row = list_items.get_row_at_index (0)) != null)
        list_items.remove (row);

      var items = get_pinned_items ();
      var has_provider = (items_provider != null);

      if (btn_add_file != null)
        btn_add_file.sensitive = has_provider;
      if (btn_add_folder != null)
        btn_add_folder.sensitive = has_provider;

      if (items.size == 0) {
        var empty_row = new Gtk.ListBoxRow ();
        empty_row.activatable = false;
        var empty_label = new Gtk.Label (has_provider
          ? _("No items yet. Use the buttons below or drag files here.")
          : _("This dock cannot accept items."));
        empty_label.margin = 12;
        empty_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        empty_row.add (empty_label);
        list_items.add (empty_row);
        empty_row.show_all ();
        return;
      }

      var index = 0;
      foreach (var item in items) {
        var item_row = make_item_row (item, index, items.size);
        list_items.add (item_row);
        item_row.show_all ();
        index++;
      }
    }

    Gtk.ListBoxRow make_item_row (DockItem item, int index, int count) {
      var row = new Gtk.ListBoxRow ();
      row.activatable = false;

      var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
      box.margin = 4;

      var image = new Gtk.Image ();
      image.set_from_pixbuf (DrawingService.load_icon (item.Icon, 32, 32));
      box.pack_start (image, false, false, 0);

      var labels = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
      labels.hexpand = true;

      var name = new Gtk.Label (item.Text != "" ? item.Text : item.Launcher);
      name.halign = Gtk.Align.START;
      name.set_ellipsize (Pango.EllipsizeMode.END);
      labels.pack_start (name, false, false, 0);

      var uri = new Gtk.Label (item.Launcher);
      uri.halign = Gtk.Align.START;
      uri.set_ellipsize (Pango.EllipsizeMode.MIDDLE);
      uri.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
      labels.pack_start (uri, false, false, 0);

      box.pack_start (labels, true, true, 0);

      var up = new Gtk.Button.from_icon_name ("go-up-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
      up.tooltip_text = _("Move up");
      up.sensitive = (index > 0);
      up.clicked.connect (() => move_item (item, -1));
      box.pack_start (up, false, false, 0);

      var down = new Gtk.Button.from_icon_name ("go-down-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
      down.tooltip_text = _("Move down");
      down.sensitive = (index < count - 1);
      down.clicked.connect (() => move_item (item, 1));
      box.pack_start (down, false, false, 0);

      var remove = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
      remove.tooltip_text = _("Remove from this dock");
      remove.clicked.connect (() => remove_item_clicked (item));
      box.pack_start (remove, false, false, 0);

      row.add (box);
      return row;
    }

    void move_item (DockItem item, int direction) {
      if (items_provider == null)
        return;

      var items = get_pinned_items ();
      var index = items.index_of (item);
      var target_index = index + direction;

      if (index < 0 || target_index < 0 || target_index >= items.size)
        return;

      items_provider.move_to (item, items[target_index]);
    }

    void remove_item_clicked (DockItem item) {
      if (items_provider == null || !items_provider.Elements.contains (item))
        return;

      // Deleting the preferences file makes the provider drop or unpin the item
      item.delete ();
    }

    void add_item_clicked (bool folder) {
      if (items_provider == null)
        return;

      var title = folder ? _("Add Folder") : _("Add File");
      var action = folder ? Gtk.FileChooserAction.SELECT_FOLDER : Gtk.FileChooserAction.OPEN;
      var dialog = new Gtk.FileChooserDialog (title, this, action,
        _("Cancel"), Gtk.ResponseType.CANCEL,
        _("Add"), Gtk.ResponseType.OK);

      dialog.select_multiple = !folder;
      dialog.local_only = false;

      if (dialog.run () == Gtk.ResponseType.OK)
        foreach (unowned string uri in dialog.get_uris ())
          add_uri_to_current_dock (uri);

      dialog.destroy ();
    }

    [CCode (instance_pos = -1)]
    void items_drag_data_received (Gtk.Widget widget, Gdk.DragContext context,
                                   int x, int y, Gtk.SelectionData data,
                                   uint info, uint time_) {
      unowned string? raw = (string?) data.get_data ();
      if (raw != null)
        foreach (unowned string uri in Uri.list_extract_uris (raw))
          add_uri_to_current_dock (uri);

      Gtk.drag_finish (context, true, false, time_);
    }

    void add_uri_to_current_dock (string uri) {
      if (items_provider == null) {
        show_message (_("This dock cannot accept items."));
        return;
      }

      if (!items_provider.add_item_with_uri (uri)) {
        var basename = File.new_for_uri (uri).get_basename () ?? uri;
        show_message (_("Could not add \"%s\" to this dock.").printf (basename));
      }
    }

    //
    // Shared dialogs
    //

    string? prompt_for_name (string title, string label, string initial) {
      var dialog = new Gtk.Dialog.with_buttons (title, this, Gtk.DialogFlags.MODAL,
        _("Cancel"), Gtk.ResponseType.CANCEL,
        _("OK"), Gtk.ResponseType.OK);
      dialog.set_default_response (Gtk.ResponseType.OK);

      var box = dialog.get_content_area ();
      box.margin = 12;
      box.spacing = 6;

      var lbl = new Gtk.Label (label);
      lbl.halign = Gtk.Align.START;
      box.add (lbl);

      var entry = new Gtk.Entry ();
      entry.text = initial;
      entry.activates_default = true;
      box.add (entry);

      dialog.show_all ();

      string? result = null;
      if (dialog.run () == Gtk.ResponseType.OK)
        result = entry.get_text ().strip ();

      dialog.destroy ();
      return result;
    }

    bool confirm (string text, string secondary) {
      var dialog = new Gtk.Dialog.with_buttons (_("Confirm"), this, Gtk.DialogFlags.MODAL,
        _("Cancel"), Gtk.ResponseType.CANCEL,
        _("Delete"), Gtk.ResponseType.OK);
      dialog.set_default_response (Gtk.ResponseType.CANCEL);

      var box = dialog.get_content_area ();
      box.margin = 12;
      box.spacing = 6;

      var label = new Gtk.Label (text);
      label.halign = Gtk.Align.START;
      box.add (label);

      var detail = new Gtk.Label (secondary);
      detail.halign = Gtk.Align.START;
      detail.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
      box.add (detail);

      dialog.show_all ();
      var response = dialog.run ();
      dialog.destroy ();

      return response == Gtk.ResponseType.OK;
    }

    void show_message (string text) {
      var dialog = new Gtk.Dialog.with_buttons (_("Plank"), this, Gtk.DialogFlags.MODAL,
        _("OK"), Gtk.ResponseType.OK);
      dialog.set_default_response (Gtk.ResponseType.OK);

      var box = dialog.get_content_area ();
      box.margin = 12;

      var label = new Gtk.Label (text);
      label.halign = Gtk.Align.START;
      label.set_line_wrap (true);
      box.add (label);

      dialog.show_all ();
      dialog.run ();
      dialog.destroy ();
    }

    [CCode (instance_pos = -1)]
    void view_drag_begin (Gtk.Widget widget, Gdk.DragContext context) {
      unowned Gtk.IconView view = (Gtk.IconView) widget;
      var selection = view.get_selected_items ();
      unowned List<Gtk.TreePath>? path_list = selection.first ();
      if (path_list == null)
        return;

      unowned Gtk.TreeModel model = view.get_model ();
      Gtk.TreeIter iter;
      GLib.Value val;
      var path = path_list.data;
      model.get_iter (out iter, path);
      model.get_value (iter, DockletViewModel.Column.ICON, out val);

      var icon_name = val.get_string ();
      var icon_size = prefs.IconSize;
      var gdk_window = get_window ();
      var window_scale_factor = gdk_window != null ? gdk_window.get_scale_factor () : get_scale_factor ();
      icon_size *= window_scale_factor;
      var surface = DrawingService.load_icon_for_scale (icon_name, icon_size, icon_size, window_scale_factor);
      surface.set_device_offset (-icon_size / 2.0, -icon_size / 2.0);
      Gtk.drag_set_icon_surface (context, surface);
    }

    [CCode (instance_pos = -1)]
    void view_item_activated (Gtk.IconView view, Gtk.TreePath path) {
      unowned ApplicationDockItemProvider? provider = (controller.default_provider as ApplicationDockItemProvider);
      if (provider == null)
        return;

      unowned Gtk.TreeModel model = view.get_model ();
      Gtk.TreeIter iter;
      GLib.Value val;
      model.get_iter (out iter, path);
      model.get_value (iter, DockletViewModel.Column.ID, out val);

      var uri = "%s%s".printf (DOCKLET_URI_PREFIX, val.get_string ());
      debug ("Try to add docklet for '%s'", uri);
      provider.add_item_with_uri (uri);
    }
  }
}
