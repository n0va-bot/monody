using Gtk;

public class TimezoneLocation {
    public string zone;
    public double latitude;
    public double longitude;

    public TimezoneLocation (string zone, double lat, double lon) {
        this.zone = zone;
        this.latitude = lat;
        this.longitude = lon;
    }
}

public class UbiquityTimezoneMap : Gtk.DrawingArea {
    private Gdk.Pixbuf? bg_pixbuf;
    private GLib.HashTable<string, Gdk.Pixbuf> loaded_overlays;
    public TimezoneLocation? selected_city;
    public GLib.List<TimezoneLocation> cities;

    private int cached_width = -1;
    private int cached_height = -1;
    private Gdk.Pixbuf? cached_bg;
    private GLib.HashTable<string, Gdk.Pixbuf> cached_overlays;

    public signal void location_changed (TimezoneLocation loc);

    public UbiquityTimezoneMap () {
        this.set_size_request (700, 358);
        this.add_events (Gdk.EventMask.BUTTON_PRESS_MASK);

        cities = new GLib.List<TimezoneLocation> ();
        loaded_overlays = new GLib.HashTable<string, Gdk.Pixbuf> (str_hash, str_equal);
        cached_overlays = new GLib.HashTable<string, Gdk.Pixbuf> (str_hash, str_equal);

        load_assets ();
        load_cities ();

        GLib.Timeout.add_seconds (1, () => {
            this.queue_draw ();
            return GLib.Source.CONTINUE;
        });
    }

    private void load_assets () {
        string base_dir = "/usr/share/monody-installer/timezone";
        if (!GLib.FileUtils.test (base_dir, GLib.FileTest.EXISTS)) {
            base_dir = "./data/timezone";
        }

        try {
            bg_pixbuf = new Gdk.Pixbuf.from_file (base_dir + "/bg.png");
        } catch (Error e) {
            warning ("Could not load timezone background: %s", e.message);
        }

        string[] zones = { "0.0", "1.0", "2.0", "3.0", "3.5", "4.0", "4.5", "5.0", "5.5", "5.75", "6.0", "6.5", "7.0", "8.0", "8.5", "9.0", "9.5", "10.0", "10.5", "11.0", "11.5", "12.0", "12.75", "13.0", "-1.0", "-2.0", "-3.0", "-3.5", "-4.0", "-4.5", "-5.0", "-5.5", "-6.0", "-7.0", "-8.0", "-9.0", "-9.5", "-10.0", "-11.0" };
        foreach (var z in zones) {
            try {
                var p = new Gdk.Pixbuf.from_file (base_dir + "/timezone_" + z + ".png");
                loaded_overlays.insert (z, p);
            } catch (Error e) {}
        }
    }

    private double parse_coord (string c, bool is_lon) {
        int sign = (c[0] == '-') ? -1 : 1;
        string num = c.substring (1);
        double deg = 0, min = 0, sec = 0;
        if (is_lon) {
            deg = double.parse (num.substring (0, 3));
            min = double.parse (num.substring (3, 2));
            if (num.length > 5)sec = double.parse (num.substring (5, 2));
        } else {
            deg = double.parse (num.substring (0, 2));
            min = double.parse (num.substring (2, 2));
            if (num.length > 4)sec = double.parse (num.substring (4, 2));
        }
        return sign * (deg + min / 60.0 + sec / 3600.0);
    }

    private void load_cities () {
        string tab_path = "/usr/share/zoneinfo/zone1970.tab";
        if (!GLib.FileUtils.test (tab_path, GLib.FileTest.EXISTS)) {
            tab_path = "/usr/share/zoneinfo/zone.tab";
        }

        string contents;
        try {
            GLib.FileUtils.get_contents (tab_path, out contents);
            foreach (string line in contents.split ("\n")) {
                if (line.strip () == "" || line.has_prefix ("#"))continue;
                string[] parts = line.split ("\t");
                if (parts.length >= 3) {
                    string coords = parts[1];
                    int split_idx = 0;
                    for (int i = 1; i < coords.length; i++) {
                        if (coords[i] == '+' || coords[i] == '-') {
                            split_idx = i;
                            break;
                        }
                    }
                    if (split_idx > 0) {
                        string lat_str = coords.substring (0, split_idx);
                        string lon_str = coords.substring (split_idx);
                        double lat = parse_coord (lat_str, false);
                        double lon = parse_coord (lon_str, true);
                        cities.append (new TimezoneLocation (parts[2], lat, lon));
                    }
                }
            }
        } catch (Error e) {
            warning ("Could not load timezone table: %s", e.message);
        }
    }

    private void get_position (double la, double lo, int width, int height, out double x_out, out double y_out) {
        double xdeg_offset = -6.0;
        double x = (width * (180.0 + lo) / 360.0)
            + (width * xdeg_offset / 180.0);
        while (x < 0)x += width;
        x = GLib.Math.fmod (x, width);

        double topLat = 81.0;
        double bottomLat = -59.0;
        double topPer = topLat / 180.0;
        double y = 1.25 * GLib.Math.log (GLib.Math.tan (GLib.Math.PI / 4.0 + 0.4 * (la * GLib.Math.PI / 180.0)));
        double fullRange = 4.6068250867599998;
        double topOffset = fullRange * topPer;
        double mapRange = GLib.Math.fabs (
                                          1.25 * GLib.Math.log (GLib.Math.tan (GLib.Math.PI / 4.0 + 0.4 * (bottomLat * GLib.Math.PI / 180.0))) - topOffset);

        y = GLib.Math.fabs (y - topOffset);
        y = y / mapRange;
        y = y * height;

        x_out = x;
        y_out = y;
    }

    public override bool button_press_event (Gdk.EventButton event) {
        int width = get_allocated_width ();
        int height = get_allocated_height ();

        TimezoneLocation? closest = null;
        double bestdist = double.MAX;

        foreach (var c in cities) {
            double cx, cy;
            get_position (c.latitude, c.longitude, width, height, out cx, out cy);
            double dx = event.x - cx;
            double dy = event.y - cy;
            double dist = dx * dx + dy * dy;
            if (dist < bestdist) {
                bestdist = dist;
                closest = c;
            }
        }

        if (closest != null) {
            set_location (closest);
        }
        return true;
    }

    public void set_location (TimezoneLocation loc) {
        this.selected_city = loc;
        this.queue_draw ();
        location_changed (loc);
    }

    public void set_timezone (string zone) {
        foreach (var c in cities) {
            if (c.zone == zone) {
                set_location (c);
                break;
            }
        }
    }

    private string ? get_closest_offset_key (double offset_hours) {
        string[] zones = { "0.0", "1.0", "2.0", "3.0", "3.5", "4.0", "4.5", "5.0", "5.5", "5.75", "6.0", "6.5", "7.0", "8.0", "8.5", "9.0", "9.5", "10.0", "10.5", "11.0", "11.5", "12.0", "12.75", "13.0", "-1.0", "-2.0", "-3.0", "-3.5", "-4.0", "-4.5", "-5.0", "-5.5", "-6.0", "-7.0", "-8.0", "-9.0", "-9.5", "-10.0", "-11.0" };
        string? best_z = null;
        double min_diff = double.MAX;

        foreach (var z in zones) {
            double z_val = double.parse (z);
            double diff = GLib.Math.fabs (z_val - offset_hours);
            if (diff < min_diff) {
                min_diff = diff;
                best_z = z;
            }
        }
        return best_z;
    }

    public override bool draw (Cairo.Context cr) {
        int width = get_allocated_width ();
        int height = get_allocated_height ();

        if (width != cached_width || height != cached_height) {
            cached_width = width;
            cached_height = height;
            if (bg_pixbuf != null) {
                cached_bg = bg_pixbuf.scale_simple (width, height, Gdk.InterpType.BILINEAR);
            }
            cached_overlays.remove_all ();
            foreach (var k in loaded_overlays.get_keys ()) {
                cached_overlays.insert (k, loaded_overlays.get (k).scale_simple (width, height, Gdk.InterpType.BILINEAR));
            }
        }

        if (cached_bg != null) {
            Gdk.cairo_set_source_pixbuf (cr, cached_bg, 0, 0);
            cr.paint ();
        }

        if (selected_city != null) {
            var tz = new GLib.TimeZone (selected_city.zone);
            var dt = new GLib.DateTime.now (tz);
            double offset_hours = dt.get_utc_offset () / 3600000000.0;

            bool is_dst = (dt.is_daylight_savings ());
            if (is_dst)offset_hours -= 1.0;

            if (offset_hours > 13.0)offset_hours -= 24.0;
            if (offset_hours < -12.0)offset_hours += 24.0;

            string? overlay_key = get_closest_offset_key (offset_hours);
            if (overlay_key != null && cached_overlays.contains (overlay_key)) {
                Gdk.cairo_set_source_pixbuf (cr, cached_overlays.get (overlay_key), 0, 0);
                cr.paint ();
            }

            double cx, cy;
            get_position (selected_city.latitude, selected_city.longitude, width, height, out cx, out cy);

            cr.set_source_rgba (1.0, 1.0, 1.0, 1.0);
            cr.arc (cx, cy, 3, 0, 2 * GLib.Math.PI);
            cr.fill ();

            string timestring = dt.format ("%H:%M");
            cr.set_font_size (12);
            Cairo.TextExtents extents;
            cr.text_extents (timestring, out extents);

            double margin = 4;
            double box_w = extents.width + margin * 2;
            double box_h = 16;
            double box_x = cx + 6;
            double box_y = cy - box_h / 2;

            if (box_x + box_w > width)box_x = cx - box_w - 6;

            cr.set_source_rgba (0.1, 0.1, 0.1, 0.8);
            cr.rectangle (box_x, box_y, box_w, box_h);
            cr.fill ();

            cr.set_source_rgba (1.0, 1.0, 1.0, 1.0);
            cr.move_to (box_x + margin, box_y + margin + extents.height - 2);
            cr.show_text (timestring);
        }

        return true;
    }
}

public class TimezonePage : Box {
    private InstallConfig config;
    private UbiquityTimezoneMap tzmap;
    private Label selection_label;
    private Entry search_entry;
    private Gtk.EntryCompletion tz_completion;
    private Gtk.ListStore tz_store;

    public TimezonePage (InstallConfig config) {
        this.config = config;
        this.orientation = Orientation.VERTICAL;
        this.spacing = 16;
        this.margin = 20;

        var header = new Label ("Where are you?");
        header.halign = Align.START;
        header.get_style_context ().add_class ("page-header");

        search_entry = new Entry ();
        search_entry.placeholder_text = "Search for a city or region...";
        search_entry.set_size_request (300, -1);
        search_entry.halign = Align.CENTER;

        tz_store = new Gtk.ListStore (1, typeof (string));

        tz_completion = new Gtk.EntryCompletion ();
        tz_completion.set_model (tz_store);
        tz_completion.set_text_column (0);
        tz_completion.set_minimum_key_length (2);
        tz_completion.set_popup_completion (true);
        tz_completion.set_match_func ((completion, key, iter) => {
            GLib.Value val;
            tz_store.get_value (iter, 0, out val);
            string tz = val.get_string ();
            if (tz == null)return false;
            return tz.down ().contains (key.down ());
        });
        search_entry.set_completion (tz_completion);

        tz_completion.match_selected.connect ((model, iter) => {
            GLib.Value val;
            model.get_value (iter, 0, out val);
            string tz = val.get_string ();
            search_entry.text = tz;
            tzmap.set_timezone (tz);
            return true;
        });

        search_entry.activate.connect (() => {
            string text = search_entry.text.strip ();
            if (text != "") {
                tzmap.set_timezone (text);
            }
        });

        tzmap = new UbiquityTimezoneMap ();
        tzmap.halign = Align.CENTER;
        tzmap.valign = Align.CENTER;

        foreach (var c in tzmap.cities) {
            Gtk.TreeIter iter;
            tz_store.append (out iter);
            tz_store.set (iter, 0, c.zone);
        }

        selection_label = new Label ("Selected: UTC");
        selection_label.halign = Align.CENTER;

        tzmap.location_changed.connect ((loc) => {
            if (loc == null)return;
            string? zone = loc.zone;
            if (zone != null && zone != "") {
                config.timezone = zone;
                selection_label.label = "Selected: " + zone;
                search_entry.text = zone;
            }
        });

        this.pack_start (header, false, false, 0);
        this.pack_start (search_entry, false, false, 0);
        this.pack_start (tzmap, true, true, 0);
        this.pack_start (selection_label, false, false, 0);
    }

    public void refresh () {
        tzmap.set_timezone ("UTC");
    }
}