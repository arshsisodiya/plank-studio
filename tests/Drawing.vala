//
//  Copyright (C) 2013 Rico Tzschichholz
//
//  This file is part of Plank.
//
//  Plank is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Plank is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

using Plank;

namespace PlankTests
{
	public static void register_drawing_tests ()
	{
		Test.add_func ("/Drawing/Color/basics", drawing_color);
		Test.add_func ("/Drawing/Color/HSV", drawing_color_hsv);
		Test.add_func ("/Drawing/Color/HSL", drawing_color_hsl);

		Test.add_func ("/Drawing/DrawingService/basics", drawing_drawingservice);
		Test.add_func ("/Drawing/DrawingService/average_color", drawing_drawingservice_average_color);

		Test.add_func ("/Drawing/Surface/basics", drawing_docksurface);
		Test.add_func ("/Drawing/Surface/create_mask", drawing_docksurface_create_mask);
		Test.add_func ("/Drawing/Surface/exponential_blur", drawing_docksurface_exponential_blur);
		Test.add_func ("/Drawing/Surface/fast_blur", drawing_docksurface_fast_blur);
		Test.add_func ("/Drawing/Surface/gaussian_blur", drawing_docksurface_gaussian_blur);
		Test.add_func ("/Drawing/Surface/to_pixbuf", drawing_docksurface_to_pixbuf);

		Test.add_func ("/Drawing/Easing/basics", drawing_easing);

		Test.add_func ("/Drawing/Theme/basics", drawing_theme);
		Test.add_func ("/Drawing/Theme/draw_background", drawing_theme_draw_background);
		Test.add_func ("/Drawing/Theme/draw_item_count", drawing_theme_draw_item_count);
		Test.add_func ("/Drawing/Theme/draw_item_progress", drawing_theme_draw_item_progress);
		Test.add_func ("/Drawing/Theme/draw_active_glow", drawing_theme_draw_active_glow);
		Test.add_func ("/Drawing/Theme/create_indicator", drawing_theme_create_indicator);
		Test.add_func ("/Drawing/Theme/create_urgent_glow", drawing_theme_create_urgent_glow);
		Test.add_func ("/Drawing/IconRounding/detection_and_clipping", drawing_icon_rounding);
		Test.add_func ("/Drawing/IconRounding/per_dock_preferences", drawing_icon_rounding_prefs);
	}

	void drawing_color ()
	{
		Color color, color2, color3;
		double h, s, v;

		color = { 0.5, 0.5, 0.5, 0.5 };
		color2 = { 0.5, 0.5, 0.5, 0.5 };
		assert (color.equal (color2));

		color3 = color;
		color3.red = 0.75;
		color3.green = 0.37;
		color3.blue = 0.66;
		color3.alpha = 0.97;
		assert (!color.equal (color3));

		color.get_hsv (out h, out s, out v);
		color2.set_hsv (h, s, v);
		assert (color.equal (color2));

		assert (color.get_hue () == 0.0);

		color = color3;
		color.set_hue (187);
		assert (color.get_hue () == 187);

		color = color3;
		color.set_sat (0.75);
		assert (color.get_sat () == 0.75);

		color = color3;
		color.set_val (0.75);
		assert (color.get_val () == 0.75);

		color = color3;
		color.set_hue (187);
		color.add_hue (15);
		assert (color.get_hue () == 202);

		color = color3;
		color.set_sat (0.35);
		color.multiply_sat (2.0);
		assert (color.get_sat () == 0.7);

		color = color3;
		color.set_min_sat (0.47);

		color = color3;
		color.set_min_val (0.52);

		color = color3;
		color.set_max_sat (0.67);

		color = color3;
		color.set_max_val (0.72);

		color = color3;
		color.darken_by_sat (0.66);

		color = Color.from_prefs_string ("123;;234;;123;;234");
		assert (color.to_prefs_string () == "123;;234;;123;;234");
	}

	void drawing_color_hsv ()
	{
		double derror;

		// HSV forth and back
		derror = 0.00000000000001;
		for (var r = 0.0; r <= 1.0; r += 0.02) { for (var g = 0.0; g <= 1.0; g += 0.02) { for (var b = 0.0; b <= 1.0; b += 0.02) {
			double h, s, v;
			Color color = { r, g, b, 1.0 };
			color.get_hsv (out h, out s, out v);
			var color2 = Color.from_hsv (h, s, v);

			assert (Math.fabs (color2.red - color.red) <= derror);
			assert (Math.fabs (color2.green - color.green) <= derror);
			assert (Math.fabs (color2.blue - color.blue) <= derror);
		}}}

		// HSV back and forth
		derror = 0.0000000001;
		for (var h = 0.0; h < 360.0; h += 3.0) { for (var s = 0.0; s <= 1.0; s += 0.02) { for (var v = 0.0; v <= 1.0; v += 0.02) {
			if ((s > 0.0 && v == 0.0)
				|| (h > 0.0 && s == 0.0))
				continue;

			double h2, s2, v2;
			var color = Color.from_hsv (h, s, v);
			Color color2 = { color.red, color.green, color.blue, 1.0 };
			color2.get_hsv (out h2, out s2, out v2);

			assert (Math.fabs (h2 - h) <= derror);
			assert (Math.fabs (s2 - s) <= derror);
			assert (Math.fabs (v2 - v) <= derror);
		}}}
	}

	void drawing_color_hsl ()
	{
		double derror;

		// HSL forth and back
		derror = 0.00000000000001;
		for (var r = 0.0; r <= 1.0; r += 0.02) { for (var g = 0.0; g <= 1.0; g += 0.02) { for (var b = 0.0; b <= 1.0; b += 0.02) {
			double h, s, l;
			Color color = { r, g, b, 1.0 };
			color.get_hsl (out h, out s, out l);
			var color2 = Color.from_hsl (h, s, l);

			assert (Math.fabs (color2.red - color.red) < derror);
			assert (Math.fabs (color2.green - color.green) < derror);
			assert (Math.fabs (color2.blue - color.blue) < derror);
		}}}

		// HSL back and forth
		derror = 0.0000000001;
		for (var h = 0.0; h < 360.0; h += 3.0) { for (var s = 0.0; s <= 1.0; s += 0.02) { for (var l = 0.0; l <= 1.0; l += 0.02) {
			if ((s > 0.0 && l == 0.0)
				|| (h > 0.0 && s == 0.0))
				continue;

			double h2, s2, l2;
			var color = Color.from_hsl (h, s, l);
			Color color2 = { color.red, color.green, color.blue, 1.0 };
			color2.get_hsl (out h2, out s2, out l2);

			assert (Math.fabs (h2 - h) <= derror);
			assert (Math.fabs (s2 - s) <= derror);
			assert (Math.fabs (l2 - l) <= derror);
		}}}
	}

	void drawing_drawingservice ()
	{
		Gdk.Pixbuf icon, icon2;

		icon = DrawingService.load_icon (TEST_ICON, 256, 256);
		assert (icon != null);
		assert (icon.width == 256);
		assert (icon.height == 256);

		icon = DrawingService.ar_scale (icon, 127, 127);
		assert (icon != null);
		assert (icon.width == 127);
		assert (icon.height == 127);

		icon2 = DrawingService.load_icon (TEST_ICON, 256, 256);
		icon2 = DrawingService.ar_scale (icon2, 1, 1);
		assert (icon2 != null);
		assert (icon2.width == 1);
		assert (icon2.height == 1);

		var icon_copy = icon.copy ();
		var color = DrawingService.average_color (icon);
		var color_copy = DrawingService.average_color (icon_copy);
		assert (color.equal (color_copy));

		icon = DrawingService.load_icon ("DOESNT_EXIST", 127, 127);
		icon2 = DrawingService.load_icon (Plank.G_RESOURCE_PATH + "/img/application-default-icon.svg", 127, 127);
		assert (pixbuf_equal (icon, icon2));

		Cairo.Surface surface;

		surface = DrawingService.load_icon_for_scale (TEST_ICON, 256, 256, 1);
		assert (surface != null);
		surface = DrawingService.load_icon_for_scale ("DOESNT_EXIST", 127, 127, 1);
		assert (surface != null);
		surface = DrawingService.load_icon_for_scale (Plank.G_RESOURCE_PATH + "/img/application-default-icon.svg", 127, 127, 1);
		assert (surface != null);
	}

	void drawing_drawingservice_average_color ()
	{
		// fully transparent surface
		drawing_drawingservice_average_color_helper ({ 0.0, 0.0, 0.0, 0.0 }, 0.0);

		// fully black surface
		drawing_drawingservice_average_color_helper ({ 0.0, 0.0, 0.0, 1.0 }, 0.0);

		// fully grey surface
		drawing_drawingservice_average_color_helper ({ 0.5, 0.5, 0.5, 1.0 }, 0.02);

		// fully white surface
		drawing_drawingservice_average_color_helper ({ 1.0, 1.0, 1.0, 1.0 }, 0.0);
	}

	void drawing_drawingservice_average_color_helper (Color color, double delta)
	{
		Color average;
		Surface surface;
		surface = new Surface (256, 256);
		unowned Cairo.Context cr = surface.Context;

		cr.set_source_rgba (color.red, color.green, color.blue, color.alpha);
		cr.set_operator (Cairo.Operator.SOURCE);
		cr.paint ();
		average = surface.average_color ();

		assert ((Math.fabs (average.red - color.red) <= delta) && (Math.fabs (average.green - color.green) <= delta)
			&& (Math.fabs (average.blue - color.blue) <= delta) && (Math.fabs (average.alpha - color.alpha) <= delta));
	}

	void drawing_docksurface ()
	{
		Surface surface, surface2, surface3, surface4;
		Gdk.Pixbuf pixbuf;

		surface = new Surface (256, 256);
		surface2 = new Surface.with_surface (256, 256, new Surface (1, 1));
		surface3 = new Surface.with_cairo_surface (256, 256, new Surface (1, 1).Internal);
		surface4 = new Surface.with_internal (new Cairo.ImageSurface (Cairo.Format.ARGB32, 256, 256));

		surface.clear ();
		surface2.clear ();
		surface3.clear ();
		surface4.clear ();

		assert (surface.Width == surface2.Width);
		assert (surface.Height == surface2.Height);
		assert (surface.Width == surface3.Width);
		assert (surface.Height == surface3.Height);
		assert (surface.Width == surface4.Width);
		assert (surface.Height == surface4.Height);

		pixbuf = surface.to_pixbuf ();
		assert (surface.Width == pixbuf.width);
		assert (surface.Height == pixbuf.height);
	}

	void drawing_docksurface_create_mask ()
	{
		Surface surface, mask;
		Gdk.Pixbuf pixbuf;

		pixbuf = DrawingService.load_icon (TEST_ICON, 256, 256);
		surface = new Surface (256, 256);

		unowned Cairo.Context cr = surface.Context;
		Gdk.cairo_set_source_pixbuf (cr, pixbuf, 0, 0);
		cr.paint ();

		Gdk.Rectangle extent;
		mask = surface.create_mask (0.0, out extent);
		mask = surface.create_mask (0.4711, out extent);
		mask = surface.create_mask (1.0, out extent);
	}

	void drawing_docksurface_fast_blur ()
	{
		Surface surface, surface2;
		Gdk.Pixbuf pixbuf;

		pixbuf = DrawingService.load_icon (TEST_ICON, 256, 256);
		surface = new Surface (256, 256);
		surface2 = new Surface (256, 256);

		unowned Cairo.Context cr = surface.Context;
		Gdk.cairo_set_source_pixbuf (cr, pixbuf, 0, 0);
		cr.paint ();

		unowned Cairo.Context cr2 = surface2.Context;
		Gdk.cairo_set_source_pixbuf (cr2, pixbuf, 0, 0);
		cr2.paint ();

		surface.fast_blur (0, 0);

		surface.fast_blur (7, 3);
		surface2.fast_blur (7, 3);
		assert (pixbuf_equal (surface.to_pixbuf (), surface2.to_pixbuf ()));

		surface.fast_blur (15, 3);
		surface2.fast_blur (15, 3);
		assert (pixbuf_equal (surface.to_pixbuf (), surface2.to_pixbuf ()));

		surface.fast_blur (31, 3);
		surface2.fast_blur (31, 3);
		assert (pixbuf_equal (surface.to_pixbuf (), surface2.to_pixbuf ()));
	}

	void drawing_docksurface_exponential_blur ()
	{
		Surface surface, surface2;
		Gdk.Pixbuf pixbuf;

		pixbuf = DrawingService.load_icon (TEST_ICON, 256, 256);
		surface = new Surface (256, 256);
		surface2 = new Surface (256, 256);

		unowned Cairo.Context cr = surface.Context;
		Gdk.cairo_set_source_pixbuf (cr, pixbuf, 0, 0);
		cr.paint ();

		unowned Cairo.Context cr2 = surface2.Context;
		Gdk.cairo_set_source_pixbuf (cr2, pixbuf, 0, 0);
		cr2.paint ();

		surface.exponential_blur (0);

		surface.exponential_blur (7);
		surface2.exponential_blur (7);
		assert (pixbuf_equal (surface.to_pixbuf (), surface2.to_pixbuf ()));

		surface.exponential_blur (15);
		surface2.exponential_blur (15);
		assert (pixbuf_equal (surface.to_pixbuf (), surface2.to_pixbuf ()));

		surface.exponential_blur (31);
		surface2.exponential_blur (31);
		assert (pixbuf_equal (surface.to_pixbuf (), surface2.to_pixbuf ()));
	}

	void drawing_docksurface_gaussian_blur ()
	{
		Surface surface, surface2;
		Gdk.Pixbuf pixbuf;

		pixbuf = DrawingService.load_icon (TEST_ICON, 256, 256);
		surface = new Surface (256, 256);
		surface2 = new Surface (256, 256);

		unowned Cairo.Context cr = surface.Context;
		Gdk.cairo_set_source_pixbuf (cr, pixbuf, 0, 0);
		cr.paint ();

		unowned Cairo.Context cr2 = surface2.Context;
		Gdk.cairo_set_source_pixbuf (cr2, pixbuf, 0, 0);
		cr2.paint ();

		surface.gaussian_blur (0);

		surface.gaussian_blur (7);
		surface2.gaussian_blur (7);
		assert (pixbuf_equal (surface.to_pixbuf (), surface2.to_pixbuf ()));

		surface.gaussian_blur (15);
		surface2.gaussian_blur (15);
		assert (pixbuf_equal (surface.to_pixbuf (), surface2.to_pixbuf ()));

		surface.gaussian_blur (31);
		surface2.gaussian_blur (31);
		assert (pixbuf_equal (surface.to_pixbuf (), surface2.to_pixbuf ()));
	}

	void drawing_docksurface_to_pixbuf ()
	{
		Surface surface, surface2;
		Gdk.Pixbuf pixbuf;

		pixbuf = DrawingService.load_icon (TEST_ICON, 256, 256);
		surface = new Surface (256, 256);
		surface2 = new Surface (256, 256);

		unowned Cairo.Context cr = surface.Context;
		Gdk.cairo_set_source_pixbuf (cr, pixbuf, 0, 0);
		cr.paint ();

		unowned Cairo.Context cr2 = surface2.Context;
		Gdk.cairo_set_source_pixbuf (cr2, pixbuf, 0, 0);
		cr2.paint ();

		assert (pixbuf_equal (surface.to_pixbuf (), surface2.to_pixbuf ()));
	}

	void drawing_easing ()
	{
		for (int i = AnimationMode.LINEAR; i < AnimationMode.LAST; i++)
			for (int j = 0; j <= 100; j++)
				easing_for_mode ((AnimationMode) i, j, 100);
	}

	void drawing_theme ()
	{
		DockTheme docktheme;
		string[] themes;
		GLib.File theme_folder;

		docktheme = new DockTheme ("Test");
		docktheme.get_top_offset ();
		docktheme.get_bottom_offset ();

		themes = Theme.get_theme_list ();
		theme_folder = Theme.get_theme_folder (Theme.DEFAULT_NAME);
		theme_folder = Theme.get_theme_folder (Theme.GTK_THEME_NAME);
		theme_folder = Theme.get_theme_folder ("Test");
	}

	void drawing_theme_draw_item_count ()
	{
		Surface surface;
		DockTheme docktheme;

		surface = new Surface (512, 512);
		docktheme = new DockTheme ("Test");
		Color color = { 0.5, 0.4, 0.3, 1.0 };

		docktheme.draw_item_count (surface, 64, color, -100);
		docktheme.draw_item_count (surface, 64, color, 0);
		docktheme.draw_item_count (surface, 64, color, 42);
		docktheme.draw_item_count (surface, 64, color, 1000);
	}

	void drawing_theme_draw_item_progress ()
	{
		Surface surface;
		DockTheme docktheme;

		surface = new Surface (512, 512);
		docktheme = new DockTheme ("Test");
		Color color = { 0.5, 0.4, 0.3, 1.0 };

		docktheme.draw_item_progress (surface, 64, color, -1.0);
		docktheme.draw_item_progress (surface, 64, color, 0);
		docktheme.draw_item_progress (surface, 64, color, 0.7);
		docktheme.draw_item_progress (surface, 64, color, 1.0);
		docktheme.draw_item_progress (surface, 64, color, 2.0);
	}

	void drawing_theme_draw_active_glow ()
	{
		Surface surface;
		DockTheme docktheme;

		surface = new Surface (512, 128);
		docktheme = new DockTheme ("Test");
		Color color = { 0.5, 0.4, 0.3, 1.0 };

		docktheme.draw_active_glow (surface, {16, 16, 480, 96}, {16, 16, 80, 80}, color, -0.1, Gtk.PositionType.BOTTOM);
		docktheme.draw_active_glow (surface, {16, 16, 480, 96}, {16, 16, 80, 80}, color, 0.1, Gtk.PositionType.BOTTOM);
		docktheme.draw_active_glow (surface, {16, 16, 480, 96}, {16, 16, 80, 80}, color, 0.5, Gtk.PositionType.TOP);
		docktheme.draw_active_glow (surface, {16, 16, 96, 480}, {16, 16, 80, 80}, color, 1.0, Gtk.PositionType.LEFT);
		docktheme.draw_active_glow (surface, {16, 16, 96, 480}, {16, 16, 80, 80}, color, 2.0, Gtk.PositionType.RIGHT);
	}

	void drawing_theme_create_indicator ()
	{
		Surface surface, surface2;
		DockTheme docktheme;

		surface = new Surface (512, 512);
		docktheme = new DockTheme ("Test");
		Color color = { 0.5, 0.4, 0.3, 1.0 };

		surface2 = docktheme.create_indicator (-1, color, surface);
		surface2 = docktheme.create_indicator (64, color, surface);
		surface2 = docktheme.create_indicator (512, color, surface);
	}

	void drawing_theme_create_urgent_glow ()
	{
		Surface surface, surface2;
		DockTheme docktheme;

		surface = new Surface (512, 512);
		docktheme = new DockTheme ("Test");
		Color color = { 0.5, 0.4, 0.3, 1.0 };

		surface2 = docktheme.create_urgent_glow (-1, color, surface);
		surface2 = docktheme.create_urgent_glow (64, color, surface);
		surface2 = docktheme.create_urgent_glow (512, color, surface);
	}

	void drawing_theme_draw_background ()
	{
		Surface surface, surface2, surface3, surface4, surface5;
		DockTheme docktheme;
		Gdk.Pixbuf pixbuf2, pixbuf3, pixbuf4, pixbuf5;

		surface = new Surface (512, 512);
		docktheme = new DockTheme ("Test");
		docktheme.draw_background (surface);

		surface.clear ();

		surface2 = docktheme.create_background (512, 128, Gtk.PositionType.BOTTOM, surface);
		pixbuf2 = surface2.to_pixbuf ();

		surface3 = docktheme.create_background (128, 512, Gtk.PositionType.RIGHT, surface);
		pixbuf3 = surface3.to_pixbuf ();
		assert (pixbuf_equal (pixbuf2, pixbuf3.rotate_simple (Gdk.PixbufRotation.CLOCKWISE)));

		surface4 = docktheme.create_background (512, 128, Gtk.PositionType.TOP, surface);
		pixbuf4 = surface4.to_pixbuf ();
		assert (pixbuf_equal (pixbuf2, pixbuf4.rotate_simple (Gdk.PixbufRotation.UPSIDEDOWN)));

		surface5 = docktheme.create_background (128, 512, Gtk.PositionType.LEFT, surface);
		pixbuf5 = surface5.to_pixbuf ();
		assert (pixbuf_equal (pixbuf2, pixbuf5.rotate_simple (Gdk.PixbufRotation.COUNTERCLOCKWISE)));
	}

	static void draw_test_rounded_rect (Cairo.Context cr, double x, double y, double w, double h, double r)
	{
		r = r.clamp (0.0, double.min (w, h) / 2.0);
		cr.new_sub_path ();
		cr.arc (x + w - r, y + r, r, -Math.PI_2, 0.0);
		cr.arc (x + w - r, y + h - r, r, 0.0, Math.PI_2);
		cr.arc (x + r, y + h - r, r, Math.PI_2, Math.PI);
		cr.arc (x + r, y + r, r, Math.PI, Math.PI + Math.PI_2);
		cr.close_path ();
	}

	uint8 test_surface_alpha_at (Surface surface, int x, int y)
	{
		var img = surface_to_image_surface (surface.Internal, surface.Width, surface.Height);
		return icon_pixel_alpha (img.get_data (), img.get_stride (), x, y);
	}

	Surface? apply_test_icon_rounding (Surface raw, int radius_percent)
	{
		Cairo.ImageSurface img;
		IconSquareBounds bounds;
		double radius;
		if (!prepare_rounded_square_icon (raw.Internal, raw.Width, raw.Height,
			radius_percent, out img, out bounds, out radius))
			return null;

		var rounded = new Surface.with_surface (raw.Width, raw.Height, raw);
		rounded.clear ();
		clip_and_paint_rounded_icon (rounded.Context, img, bounds, radius);
		return rounded;
	}

	void drawing_icon_rounding ()
	{
		// 1. Full-bleed 48x48 opaque square icon
		var full_sq = new Surface (48, 48);
		full_sq.Context.set_source_rgba (0.2, 0.5, 0.9, 1.0);
		full_sq.Context.rectangle (0, 0, 48, 48);
		full_sq.Context.fill ();

		var full_img = surface_to_image_surface (full_sq.Internal, 48, 48);
		var full_bounds = detect_square_icon_bounds (full_img);
		assert (full_bounds.is_square);
		assert (full_bounds.x == 0 && full_bounds.y == 0);
		assert (full_bounds.width == 48 && full_bounds.height == 48);

		var rounded_subtle = apply_test_icon_rounding (full_sq, 10);
		assert (rounded_subtle != null);
		assert (test_surface_alpha_at (rounded_subtle, 0, 0) == 0);
		assert (test_surface_alpha_at (rounded_subtle, 47, 0) == 0);
		assert (test_surface_alpha_at (rounded_subtle, 0, 47) == 0);
		assert (test_surface_alpha_at (rounded_subtle, 47, 47) == 0);
		assert (test_surface_alpha_at (rounded_subtle, 24, 24) == 255);
		// Subtle 10% (4.8px radius) keeps (4, 1) well inside the rounded corner
		assert (test_surface_alpha_at (rounded_subtle, 4, 1) == 255);

		var rounded_strong = apply_test_icon_rounding (full_sq, 25);
		assert (rounded_strong != null);
		// Strong 25% (12px radius) clips (4, 1) cleanly to transparent
		assert (test_surface_alpha_at (rounded_strong, 4, 1) == 0);
		assert (test_surface_alpha_at (rounded_strong, 24, 24) == 255);

		// 2. Padded square icon (40x40 inside transparent 4px margins)
		var padded_sq = new Surface (48, 48);
		padded_sq.Context.set_source_rgba (0.9, 0.3, 0.2, 1.0);
		padded_sq.Context.rectangle (4, 4, 40, 40);
		padded_sq.Context.fill ();

		var padded_img = surface_to_image_surface (padded_sq.Internal, 48, 48);
		var padded_bounds = detect_square_icon_bounds (padded_img);
		assert (padded_bounds.is_square);
		assert (padded_bounds.x == 4 && padded_bounds.y == 4);
		assert (padded_bounds.width == 40 && padded_bounds.height == 40);

		var padded_rounded = apply_test_icon_rounding (padded_sq, 15);
		assert (padded_rounded != null);
		assert (test_surface_alpha_at (padded_rounded, 4, 4) == 0);
		assert (test_surface_alpha_at (padded_rounded, 43, 4) == 0);
		assert (test_surface_alpha_at (padded_rounded, 4, 43) == 0);
		assert (test_surface_alpha_at (padded_rounded, 43, 43) == 0);
		assert (test_surface_alpha_at (padded_rounded, 24, 24) == 255);

		// 3. Native 5px rounded icon with baked faint outer shadow (alpha ~40)
		var native_rounded = new Surface (48, 48);
		native_rounded.Context.set_source_rgba (0.0, 0.0, 0.0, 0.15);
		draw_test_rounded_rect (native_rounded.Context, 2, 3, 44, 44, 5.0);
		native_rounded.Context.fill ();
		native_rounded.Context.set_source_rgba (0.3, 0.7, 0.4, 1.0);
		draw_test_rounded_rect (native_rounded.Context, 4, 4, 40, 40, 5.0);
		native_rounded.Context.fill ();

		assert (apply_test_icon_rounding (native_rounded, 25) == null);

		// 4. Circular icon stays untouched
		var circle = new Surface (48, 48);
		circle.Context.set_source_rgba (0.1, 0.6, 0.8, 1.0);
		circle.Context.arc (24, 24, 21, 0, 2 * Math.PI);
		circle.Context.fill ();
		assert (apply_test_icon_rounding (circle, 20) == null);

		// 5. Thin separator bar stays untouched
		var separator = new Surface (48, 48);
		separator.Context.set_source_rgba (1.0, 1.0, 1.0, 1.0);
		separator.Context.rectangle (22, 4, 4, 40);
		separator.Context.fill ();
		assert (apply_test_icon_rounding (separator, 15) == null);
	}

	void drawing_icon_rounding_prefs ()
	{
		var prefs1 = new DockPreferences ("round_test_dock1");
		var prefs2 = new DockPreferences ("round_test_dock2");

		assert (!prefs1.RoundSquareIcons);
		assert (prefs1.IconCornerRadius == 10);

		prefs1.RoundSquareIcons = true;
		prefs1.IconCornerRadius = 18;
		assert (!prefs2.RoundSquareIcons);
		assert (prefs2.IconCornerRadius == 10);

		prefs1.IconCornerRadius = DockPreferences.MIN_ICON_CORNER_RADIUS;
		assert (prefs1.IconCornerRadius == 4);
		prefs1.IconCornerRadius = DockPreferences.MAX_ICON_CORNER_RADIUS;
		assert (prefs1.IconCornerRadius == 30);
		assert (prefs2.IconCornerRadius == 10);
	}
}
