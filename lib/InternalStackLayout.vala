//
// Copyright (C) 2026 Plank Reloaded Developers
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
   * Pure math output for one frame of a stackable dock item.
   */
  public struct StackItemLayout {
    public double x;
    public double y;
    public double icon_size;
    public double opacity;
    public double progress;
  }

  /**
   * Complete layout computation for a stackable dock at a given animation state.
   */
  public struct StackFrameLayout {
    public double anchor_x;
    public double anchor_y;
    public double anchor_opacity;
    public double anchor_scale;
    public double fitted_icon_size;
    public double fitted_spacing;
    public Gdk.Rectangle background_rect;
    public Gdk.Rectangle cursor_rect;
    public StackItemLayout[] items;
  }

  /**
   * Maps a direction index (0=UP, 1=DOWN, 2=LEFT, 3=RIGHT) to unit axis steps.
   *
   * @param direction_val integer value of StackDirection
   * @param dx output horizontal step (-1, 0, or 1)
   * @param dy output vertical step (-1, 0, or 1)
   */
  public static void stack_direction_vector (int direction_val, out int dx, out int dy) {
    switch (direction_val) {
    default:
    case 0: // UP
      dx = 0;
      dy = -1;
      break;
    case 1: // DOWN
      dx = 0;
      dy = 1;
      break;
    case 2: // LEFT
      dx = -1;
      dy = 0;
      break;
    case 3: // RIGHT
      dx = 1;
      dy = 0;
      break;
    }
  }

  /**
   * Smooth cubic ease-out helper on [0.0, 1.0].
   */
  public static double stack_ease_out_cubic (double t) {
    var clamped = double.max (0.0, double.min (1.0, t));
    var inv = 1.0 - clamped;
    return 1.0 - inv * inv * inv;
  }

  /**
   * Quintic smoothstep interpolation between edge0 and edge1.
   */
  public static double stack_smoothstep (double edge0, double edge1, double x) {
    if (edge1 <= edge0)
      return x >= edge1 ? 1.0 : 0.0;
    var s = double.max (0.0, double.min (1.0, (x - edge0) / (edge1 - edge0)));
    return s * s * (3.0 - 2.0 * s);
  }

  /**
   * Evaluates a CSS-style cubic-bezier(x1, y1, x2, y2) timing curve on [0.0, 1.0].
   */
  public static double stack_cubic_bezier (double t, double x1, double y1, double x2, double y2) {
    var target = double.max (0.0, double.min (1.0, t));
    if (target <= 0.0)
      return 0.0;
    if (target >= 1.0)
      return 1.0;

    var cx = 3.0 * x1;
    var bx = 3.0 * (x2 - x1) - cx;
    var ax = 1.0 - cx - bx;

    var u = target;
    for (var i = 0; i < 6; i++) {
      var x = ((ax * u + bx) * u + cx) * u - target;
      if (Math.fabs (x) < 1e-6)
        break;
      var dx = (3.0 * ax * u + 2.0 * bx) * u + cx;
      if (Math.fabs (dx) < 1e-6)
        break;
      u = double.max (0.0, double.min (1.0, u - x / dx));
    }

    var lo = 0.0;
    var hi = 1.0;
    if (Math.fabs (((ax * u + bx) * u + cx) * u - target) > 1e-4) {
      u = target;
      for (var i = 0; i < 12; i++) {
        var x = ((ax * u + bx) * u + cx) * u;
        if (Math.fabs (x - target) < 1e-6)
          break;
        if (x < target)
          lo = u;
        else
          hi = u;
        u = 0.5 * (lo + hi);
      }
    }

    var cy = 3.0 * y1;
    var by = 3.0 * (y2 - y1) - cy;
    var ay = 1.0 - cy - by;
    return double.max (0.0, double.min (1.0, ((ay * u + by) * u + cy) * u));
  }

  /**
   * Direction-aware fluid stack easing curve on [0.0, 1.0].
   */
  public static double stack_ease_curve (double t, bool expanding) {
    return expanding
      ? stack_cubic_bezier (t, 0.16, 1.0, 0.30, 1.0)
      : stack_cubic_bezier (t, 0.32, 0.0, 0.22, 1.0);
  }

  /**
   * Computes normalized linear animation progress in [0.0, 1.0], supporting
   * glitch-free mid-flight reversal from any starting progress.
   */
  public static double stack_compute_linear_progress (bool expanded, double start_progress,
                                                      int64 toggle_time, int64 frame_time,
                                                      int duration_ms) {
    var clamped_start = double.max (0.0, double.min (1.0, start_progress));
    var target = expanded ? 1.0 : 0.0;
    var distance = Math.fabs (target - clamped_start);
    if (distance <= 0.0001 || duration_ms <= 0 || toggle_time <= 0)
      return target;

    var effective_duration = duration_ms * 1000.0 * distance;
    var elapsed = double.max (0.0, (double) (frame_time - toggle_time));
    var frac = double.min (1.0, elapsed / effective_duration);
    return clamped_start + (target - clamped_start) * frac;
  }

  /**
   * Computes an item's eased progress on [0.0, 1.0] with outward stagger on
   * expand, reverse stagger on collapse, and seamless mid-flight reversal.
   */
  public static double stack_staggered_progress (bool expanded, double start_progress,
                                                   int64 toggle_time, int64 frame_time,
                                                   int duration_ms, int index, int count) {
    var clamped_start = double.max (0.0, double.min (1.0, start_progress));
    var target = expanded ? 1.0 : 0.0;
    var distance = Math.fabs (target - clamped_start);
    if (distance <= 0.0001 || duration_ms <= 0 || toggle_time <= 0)
      return target;

    var effective_duration = duration_ms * 1000.0 * distance;
    var elapsed = double.max (0.0, (double) (frame_time - toggle_time));
    var frac = double.min (1.0, elapsed / effective_duration);

    if (count <= 1)
      return clamped_start + (target - clamped_start) * stack_ease_curve (frac, expanded);

    var max_stagger = double.min (0.28, (count - 1) * 0.042);
    var active_span = 1.0 - max_stagger;
    var order = expanded ? index : (count - 1 - index);
    var delay = (order / (double) (count - 1)) * max_stagger;
    var local_frac = double.max (0.0, double.min (1.0, (frac - delay) / active_span));

    return clamped_start + (target - clamped_start) * stack_ease_curve (local_frac, expanded);
  }

  /**
   * Computes fitted icon size, spacing, target positions, collapsed deck cards,
   * and continuous background/cursor rectangles for all items along any expansion
   * direction, clamped safely within usable window-relative monitor bounds.
   * Pure geometry function — testable without X11 or GTK widgets.
   */
  public static StackFrameLayout compute_stack_frame_layout (
    double origin_x, double origin_y,
    int direction_val,
    int icon_size, int item_spacing,
    int pad_x, int pad_y,
    Gdk.Rectangle usable_bounds,
    Gdk.Rectangle collapsed_bg_rect,
    double[] item_progresses,
    double handle_progress
  ) {
    int dx, dy;
    stack_direction_vector (direction_val, out dx, out dy);

    bool horizontal_expand = (dx != 0);
    int item_count = item_progresses.length;
    int total_slots = item_count + 1;

    var avail_min = horizontal_expand ? usable_bounds.x : usable_bounds.y;
    var avail_max = horizontal_expand ? (usable_bounds.x + usable_bounds.width)
                                      : (usable_bounds.y + usable_bounds.height);
    var avail_span = int.max (icon_size + 2 * (horizontal_expand ? pad_x : pad_y),
                              avail_max - avail_min);

    var axis_pad = horizontal_expand ? pad_x : pad_y;
    var cross_pad = horizontal_expand ? pad_y : pad_x;
    var outer_margin = 4;
    var max_content_span = double.max ((double) icon_size, (double) (avail_span - 2 * axis_pad - 2 * outer_margin));

    // Fit expanded items smoothly into smaller displays without clipping.
    double fitted_icon = (double) icon_size;
    double fitted_spacing = (double) int.max (0, item_spacing);
    if (item_count > 0) {
      var unscaled_span = total_slots * fitted_icon + item_count * fitted_spacing;
      if (unscaled_span > max_content_span) {
        var min_spacing = double.min (fitted_spacing, 4.0);
        var reduced_span = total_slots * fitted_icon + item_count * min_spacing;
        if (reduced_span <= max_content_span) {
          fitted_spacing = (max_content_span - total_slots * fitted_icon) / (double) item_count;
        } else {
          fitted_spacing = min_spacing;
          var icon_budget = max_content_span - item_count * fitted_spacing;
          fitted_icon = double.max (16.0, icon_budget / (double) total_slots);
        }
      }
    }

    var step = fitted_icon + fitted_spacing;
    var half_slot = fitted_icon / 2.0;

    // Cross-axis clamping so the origin stays wholly inside usable bounds.
    var cross_min = horizontal_expand ? usable_bounds.y : usable_bounds.x;
    var cross_max = horizontal_expand ? (usable_bounds.y + usable_bounds.height)
                                      : (usable_bounds.x + usable_bounds.width);
    var clamped_origin_x = origin_x;
    var clamped_origin_y = origin_y;
    if (horizontal_expand) {
      clamped_origin_y = double.max (cross_min + half_slot + cross_pad,
                                     double.min (cross_max - half_slot - cross_pad, origin_y));
    } else {
      clamped_origin_x = double.max (cross_min + half_slot + cross_pad,
                                     double.min (cross_max - half_slot - cross_pad, origin_x));
    }

    // Clamp the expanded span along the expansion axis so edge docks never clip.
    var axis_origin = horizontal_expand ? clamped_origin_x : clamped_origin_y;
    var dir_sign = horizontal_expand ? dx : dy;
    var end_center = axis_origin + dir_sign * item_count * step;
    var span_min = double.min (axis_origin, end_center) - half_slot - axis_pad;
    var span_max = double.max (axis_origin, end_center) + half_slot + axis_pad;

    var axis_shift = 0.0;
    if (span_min < avail_min + outer_margin)
      axis_shift = (avail_min + outer_margin) - span_min;
    if (span_max + axis_shift > avail_max - outer_margin)
      axis_shift = (avail_max - outer_margin) - span_max;
    if (span_min + axis_shift < avail_min + outer_margin)
      axis_shift = ((avail_min + avail_max) / 2.0) - ((span_min + span_max) / 2.0);

    var target_anchor_x = clamped_origin_x + (horizontal_expand ? axis_shift : 0.0);
    var target_anchor_y = clamped_origin_y + (horizontal_expand ? 0.0 : axis_shift);

    // Determine effective peek direction pointing toward the expanded item 0 so
    // collapsed cards always peek cleanly inside the screen even against edges.
    var peek_step = double.max (3.0, icon_size * 0.11);
    var first_target_dx = (target_anchor_x + dx * step) - origin_x;
    var first_target_dy = (target_anchor_y + dy * step) - origin_y;
    var peek_len = Math.hypot (first_target_dx, first_target_dy);
    var peek_ux = (peek_len > 0.01) ? (first_target_dx / peek_len) : (double) dx;
    var peek_uy = (peek_len > 0.01) ? (first_target_dy / peek_len) : (double) dy;

    StackFrameLayout result = {};
    result.anchor_x = origin_x + (target_anchor_x - origin_x) * handle_progress;
    result.anchor_y = origin_y + (target_anchor_y - origin_y) * handle_progress;
    result.anchor_opacity = stack_smoothstep (0.16, 0.88, handle_progress);
    result.anchor_scale = 0.78 + 0.22 * handle_progress;
    result.fitted_icon_size = fitted_icon;
    result.fitted_spacing = fitted_spacing;
    result.items = new StackItemLayout[item_count];

    double min_x = result.anchor_x - (fitted_icon / 2.0) * result.anchor_scale;
    double max_x = result.anchor_x + (fitted_icon / 2.0) * result.anchor_scale;
    double min_y = result.anchor_y - (fitted_icon / 2.0) * result.anchor_scale;
    double max_y = result.anchor_y + (fitted_icon / 2.0) * result.anchor_scale;

    for (var i = 0; i < item_count; i++) {
      var p = double.max (0.0, double.min (1.0, item_progresses[i]));

      double col_scale;
      double col_opacity;
      double peek_mult;
      if (i == 0) {
        col_scale = 0.94;
        col_opacity = 1.0;
        peek_mult = 0.0;
      } else if (i == 1) {
        col_scale = 0.84;
        col_opacity = 0.80;
        peek_mult = 1.0;
      } else if (i == 2) {
        col_scale = 0.74;
        col_opacity = 0.58;
        peek_mult = 2.0;
      } else {
        col_scale = 0.72;
        col_opacity = 0.0;
        peek_mult = 2.0;
      }

      var col_x = origin_x + peek_ux * peek_step * peek_mult;
      var col_y = origin_y + peek_uy * peek_step * peek_mult;
      var tgt_x = target_anchor_x + dx * ((i + 1) * step);
      var tgt_y = target_anchor_y + dy * ((i + 1) * step);

      var cur_x = col_x + (tgt_x - col_x) * p;
      var cur_y = col_y + (tgt_y - col_y) * p;
      var cur_size = (icon_size * col_scale) + (fitted_icon - icon_size * col_scale) * p;

      double cur_opacity;
      if (i < 3) {
        cur_opacity = col_opacity + (1.0 - col_opacity) * p;
      } else {
        cur_opacity = stack_smoothstep (0.06, 0.55, p);
      }

      result.items[i] = {
        cur_x,
        cur_y,
        cur_size,
        cur_opacity,
        p
      };

      if (cur_opacity > 0.05 || p > 0.05) {
        var half_i = cur_size / 2.0;
        min_x = double.min (min_x, cur_x - half_i);
        max_x = double.max (max_x, cur_x + half_i);
        min_y = double.min (min_y, cur_y - half_i);
        max_y = double.max (max_y, cur_y + half_i);
      }
    }

    // Blend smoothly from collapsed_bg_rect to the live item bounding box early
    // in the animation so icons stay snugly wrapped inside the background.
    bool has_visible_bg = (collapsed_bg_rect.width > 0 && collapsed_bg_rect.height > 0);
    if (has_visible_bg) {
      var exp_min_x = (int) Math.floor (min_x - pad_x);
      var exp_max_x = (int) Math.ceil (max_x + pad_x);
      var exp_min_y = (int) Math.floor (min_y - pad_y);
      var exp_max_y = (int) Math.ceil (max_y + pad_y);
      var col_right = collapsed_bg_rect.x + collapsed_bg_rect.width;
      var col_bottom = collapsed_bg_rect.y + collapsed_bg_rect.height;

      var bg_blend = stack_ease_out_cubic (double.min (1.0, handle_progress * 1.45));
      var bg_left = (int) Math.round (collapsed_bg_rect.x + (exp_min_x - collapsed_bg_rect.x) * bg_blend);
      var bg_top = (int) Math.round (collapsed_bg_rect.y + (exp_min_y - collapsed_bg_rect.y) * bg_blend);
      var bg_right = (int) Math.round (col_right + (exp_max_x - col_right) * bg_blend);
      var bg_bottom = (int) Math.round (col_bottom + (exp_max_y - col_bottom) * bg_blend);

      var bg_x = int.max (usable_bounds.x, bg_left);
      var bg_y = int.max (usable_bounds.y, bg_top);
      var bg_w = int.min (int.max (1, bg_right - bg_x), usable_bounds.x + usable_bounds.width - bg_x);
      var bg_h = int.min (int.max (1, bg_bottom - bg_y), usable_bounds.y + usable_bounds.height - bg_y);

      result.background_rect = {
        bg_x,
        bg_y,
        int.max (1, bg_w),
        int.max (1, bg_h)
      };
    } else {
      result.background_rect = { 0, 0, 0, 0 };
    }

    // Always span all visible items/badge (even on shelf-only themes where
    // collapsed_bg_rect is only a thin edge strip) and union the background.
    var cur_left = int.max (usable_bounds.x, (int) Math.floor (min_x - 6));
    var cur_top = int.max (usable_bounds.y, (int) Math.floor (min_y - 6));
    var cur_right = int.min (usable_bounds.x + usable_bounds.width, (int) Math.ceil (max_x + 6));
    var cur_bottom = int.min (usable_bounds.y + usable_bounds.height, (int) Math.ceil (max_y + 6));
    if (has_visible_bg) {
      cur_left = int.min (cur_left, result.background_rect.x);
      cur_top = int.min (cur_top, result.background_rect.y);
      cur_right = int.max (cur_right, result.background_rect.x + result.background_rect.width);
      cur_bottom = int.max (cur_bottom, result.background_rect.y + result.background_rect.height);
    }
    result.cursor_rect = {
      cur_left,
      cur_top,
      int.max (1, cur_right - cur_left),
      int.max (1, cur_bottom - cur_top)
    };

    return result;
  }
}
