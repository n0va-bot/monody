using Gtk;

public class TimezonePage : Box {
    private InstallConfig config;
    private Cc.TimezoneMap tzmap;
    private Label selection_label;
    private Entry search_entry;
    private Gtk.EntryCompletion tz_completion;
    private Gtk.ListStore tz_store;

    public TimezonePage (InstallConfig config) {
        this.config = config;
        this.orientation = Orientation.VERTICAL;
        this.spacing = 16;
        this.margin = 40;

        var header_box = new Box (Orientation.VERTICAL, 6);
        header_box.valign = Align.START;
        header_box.halign = Align.CENTER;

        var header = new Label ("Where are you?");
        header.get_style_context ().add_class ("page-header");
        
        var desc = new Label ("Select your location on the map to set your timezone.");
        desc.get_style_context ().add_class ("page-desc");

        header_box.pack_start (header, false, false, 0);
        header_box.pack_start (desc, false, false, 0);

        search_entry = new Entry ();
        search_entry.placeholder_text = "Search for a city or region...";
        search_entry.set_size_request (300, -1);
        search_entry.halign = Align.CENTER;

        tz_store = new Gtk.ListStore (1, typeof (string));
        populate_timezones ();

        tz_completion = new Gtk.EntryCompletion ();
        tz_completion.set_model (tz_store);
        tz_completion.set_text_column (0);
        tz_completion.set_minimum_key_length (2);
        tz_completion.set_popup_completion (true);
        tz_completion.set_match_func ((completion, key, iter) => {
            GLib.Value val;
            tz_store.get_value (iter, 0, out val);
            string tz = val.get_string ();
            if (tz == null) return false;
            return tz.down ().contains (key.down ());
        });
        search_entry.set_completion (tz_completion);

        tz_completion.match_selected.connect ((model, iter) => {
            GLib.Value val;
            model.get_value (iter, 0, out val);
            string tz = val.get_string ();
            search_entry.text = tz;
            tzmap.set_timezone (tz);
            config.timezone = tz;
            selection_label.label = "Selected: " + tz;
            return true;
        });

        search_entry.activate.connect (() => {
            string text = search_entry.text.strip ();
            if (text != "") {
                tzmap.set_timezone (text);
                config.timezone = text;
                selection_label.label = "Selected: " + text;
            }
        });

        tzmap = new Cc.TimezoneMap ();
        tzmap.set_size_request (600, 300);
        tzmap.halign = Align.CENTER;

        selection_label = new Label ("Selected: UTC");
        selection_label.get_style_context ().add_class ("form-label");
        selection_label.halign = Align.CENTER;

        tzmap.location_changed.connect ((loc) => {
            if (loc == null) return;
            string? zone = loc.get_zone ();
            if (zone != null && zone != "") {
                config.timezone = zone;
                selection_label.label = "Selected: " + zone;
                search_entry.text = zone;
            }
        });

        this.pack_start (header_box, false, false, 0);
        this.pack_start (search_entry, false, false, 0);
        this.pack_start (tzmap, true, true, 0);
        this.pack_start (selection_label, false, false, 0);
    }

    private void populate_timezones () {
        string output = Utils.run_sync ("find /usr/share/zoneinfo/posix -type f -printf '%P\n'");
        string[] lines = output.split ("\n");
        foreach (string line in lines) {
            string tz = line.strip ();
            if (tz == "" || tz.has_prefix ("posix/") || tz.has_prefix ("right/")) continue;
            if (!tz.contains ("/")) continue;
            Gtk.TreeIter iter;
            tz_store.append (out iter);
            tz_store.set (iter, 0, tz);
        }
    }

    public void refresh () {
        tzmap.set_timezone ("UTC");
    }
}