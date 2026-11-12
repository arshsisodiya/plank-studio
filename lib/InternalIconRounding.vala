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
  public struct IconSquareBounds {
    public int x;
    public int y;
    public int width;
    public int height;
    public bool is_square;
  }

  public inline uint8 icon_pixel_alpha (uint8[] data, int stride, int x, int y) {
    int offset = y * stride + x * 4 + (ByteOrder.HOST == ByteOrder.LITTLE_ENDIAN ? 3 : 0);
    return data[offset];
  }

  internal bool edge_segment_is_solid (uint8[] data, int stride, int start_x, int start_y,
                                       int dx, int dy, int length,
                                       int inward_dx, int inward_dy, int tol,
                                       uint8 threshold) {
    if (length <= 0)
      return false;

    int hits = 0;
    for (int i = 0; i < length; i++) {
      int px = start_x + dx * i;
      int py = start_y + dy * i;
      bool found = false;
      for (int t = 0; t <= tol; t++) {
        if (icon_pixel_alpha (data, stride, px + inward_dx * t, py + inward_dy * t) >= threshold) {
          found = true;
          break;
        }
      }
      if (found)
        hits++;
    }

    return hits * 4 >= length * 3;
  }

  internal bool corner_vertex_is_opaque (uint8[] data, int stride, int corner_x, int corner_y,
                                         int dir_x, int dir_y, int tol, uint8 threshold) {
    for (int dy = 0; dy <= tol; dy++) {
      for (int dx = 0; dx <= tol - dy; dx++) {
        if (icon_pixel_alpha (data, stride, corner_x + dir_x * dx, corner_y + dir_y * dy) >= threshold)
          return true;
      }
    }
    return false;
  }

  /**
   * Analyzes an ARGB32 image surface to find its opaque content bounding box
   * and determine whether it has sharp square corners rather than already-rounded,
   * circular, or non-rectangular geometry.
   */
  public IconSquareBounds detect_square_icon_bounds (Cairo.ImageSurface img) {
    int w = img.get_width ();
    int h = img.get_height ();
    if (w < 8 || h < 8)
      return { 0, 0, 0, 0, false };

    img.flush ();
    int stride = img.get_stride ();
    unowned uint8[] data = img.get_data ();
    if (data == null || stride < w * 4)
      return { 0, 0, 0, 0, false };

    // Use a high alpha threshold so faint baked outer drop shadows around
    // already-rounded icon themes (e.g. Adwaita/Papirus) are ignored.
    const uint8 OPAQUE_THRESHOLD = 180;

    int min_x = w;
    int min_y = h;
    int max_x = -1;
    int max_y = -1;

    for (int y = 0; y < h; y++) {
      int row_offset = y * stride + (ByteOrder.HOST == ByteOrder.LITTLE_ENDIAN ? 3 : 0);
      for (int x = 0; x < w; x++) {
        if (data[row_offset + x * 4] >= OPAQUE_THRESHOLD) {
          if (x < min_x) min_x = x;
          if (x > max_x) max_x = x;
          if (y < min_y) min_y = y;
          if (y > max_y) max_y = y;
        }
      }
    }

    if (max_x < min_x || max_y < min_y)
      return { 0, 0, 0, 0, false };

    int bw = max_x - min_x + 1;
    int bh = max_y - min_y + 1;
    if (bw < int.max (8, (int) (w * 0.55)) || bh < int.max (8, (int) (h * 0.55)))
      return { min_x, min_y, bw, bh, false };

    int min_side = int.min (bw, bh);
    int max_side = int.max (bw, bh);
    if ((double) min_side / (double) max_side < 0.85)
      return { min_x, min_y, bw, bh, false };

    // Verify the middle half of each bounding edge is solid so circular,
    // triangular, diamond, or star-shaped icons are not treated as squares.
    int edge_tol = int.min (2, int.max (1, (int) Math.floor (min_side * 0.02)));
    int mid_x = min_x + bw / 4;
    int span_x = int.max (1, bw / 2);
    int mid_y = min_y + bh / 4;
    int span_y = int.max (1, bh / 2);

    if (!edge_segment_is_solid (data, stride, mid_x, min_y, 1, 0, span_x, 0, 1, edge_tol, OPAQUE_THRESHOLD)
        || !edge_segment_is_solid (data, stride, mid_x, max_y, 1, 0, span_x, 0, -1, edge_tol, OPAQUE_THRESHOLD)
        || !edge_segment_is_solid (data, stride, min_x, mid_y, 0, 1, span_y, 1, 0, edge_tol, OPAQUE_THRESHOLD)
        || !edge_segment_is_solid (data, stride, max_x, mid_y, 0, 1, span_y, -1, 0, edge_tol, OPAQUE_THRESHOLD))
      return { min_x, min_y, bw, bh, false };

    int corner_tol = int.min (2, int.max (1, (int) Math.floor (min_side * 0.025)));
    int square_corners = 0;
    if (corner_vertex_is_opaque (data, stride, min_x, min_y, 1, 1, corner_tol, OPAQUE_THRESHOLD))
      square_corners++;
    if (corner_vertex_is_opaque (data, stride, max_x, min_y, -1, 1, corner_tol, OPAQUE_THRESHOLD))
      square_corners++;
    if (corner_vertex_is_opaque (data, stride, min_x, max_y, 1, -1, corner_tol, OPAQUE_THRESHOLD))
      square_corners++;
    if (corner_vertex_is_opaque (data, stride, max_x, max_y, -1, -1, corner_tol, OPAQUE_THRESHOLD))
      square_corners++;

    return { min_x, min_y, bw, bh, square_corners >= 3 };
  }

  internal double compute_icon_corner_radius (int box_width, int box_height, int radius_percent) {
    double min_dim = (double) int.min (box_width, box_height);
    if (min_dim <= 0.0)
      return 0.0;
    return (min_dim * radius_percent.clamp (0, 50) / 100.0).clamp (0.0, min_dim / 2.0);
  }

  internal void clip_rounded_box (Cairo.Context cr, double x, double y, double w, double h, double radius) {
    double r = radius.clamp (0.0, double.min (w, h) / 2.0);
    cr.new_sub_path ();
    cr.arc (x + w - r, y + r, r, -Math.PI_2, 0.0);
    cr.arc (x + w - r, y + h - r, r, 0.0, Math.PI_2);
    cr.arc (x + r, y + h - r, r, Math.PI_2, Math.PI);
    cr.arc (x + r, y + r, r, Math.PI, Math.PI + Math.PI_2);
    cr.close_path ();
    cr.clip ();
  }

  public Cairo.ImageSurface surface_to_image_surface (Cairo.Surface src, int width, int height) {
    var img = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
    var cr = new Cairo.Context (img);

    double sx = 1.0, sy = 1.0;
    src.get_device_scale (out sx, out sy);
    if (sx != 1.0 || sy != 1.0)
      src.set_device_scale (1.0, 1.0);

    cr.set_operator (Cairo.Operator.SOURCE);
    cr.set_source_surface (src, 0.0, 0.0);
    cr.paint ();

    if (sx != 1.0 || sy != 1.0)
      src.set_device_scale (sx, sy);

    img.flush ();
    return img;
  }

  /**
   * Analyzes a Cairo surface and returns the pixel data, square bounds, and
   * corner radius if rounding should be applied.
   */
  public bool prepare_rounded_square_icon (Cairo.Surface src, int width, int height,
    int radius_percent, out Cairo.ImageSurface img_out,
    out IconSquareBounds bounds_out, out double radius_out)
  {
    img_out = null;
    bounds_out = IconSquareBounds ();
    radius_out = 0.0;

    if (radius_percent <= 0 || width < 8 || height < 8)
      return false;

    var img = surface_to_image_surface (src, width, height);
    var bounds = detect_square_icon_bounds (img);
    if (!bounds.is_square)
      return false;

    double radius = compute_icon_corner_radius (bounds.width, bounds.height, radius_percent);
    if (radius <= 0.5)
      return false;

    img_out = img;
    bounds_out = bounds;
    radius_out = radius;
    return true;
  }

  /**
   * Paints an image surface clipped to a rounded rectangle onto a target context.
   */
  public void clip_and_paint_rounded_icon (Cairo.Context cr, Cairo.ImageSurface img,
    IconSquareBounds bounds, double radius)
  {
    cr.save ();
    clip_rounded_box (cr, bounds.x, bounds.y, bounds.width, bounds.height, radius);
    cr.set_operator (Cairo.Operator.SOURCE);
    cr.set_source_surface (img, 0.0, 0.0);
    cr.paint ();
    cr.restore ();
  }
}
