using Gtk;

public class UserPage : Box {
    private InstallConfig config;

    private Entry hostname_entry;
    private Entry display_name_entry;
    private Entry username_entry;
    private Entry user_pass_entry;
    private Entry user_pass_confirm;
    private Entry root_pass_entry;
    private ComboBoxText swap_combo;
    private Label validation_label;

    private bool auto_username = true;
    public signal void validation_changed (bool valid);

    public UserPage (InstallConfig config) {
        this.config = config;
        this.orientation = Orientation.VERTICAL;
        this.spacing = 12;
        this.margin = 30;

        var header = new Label ("User & System");
        header.get_style_context ().add_class ("page-header");
        header.xalign = 0;

        var desc = new Label ("Configure your user account, hostname, and swap space.");
        desc.get_style_context ().add_class ("page-desc");
        desc.xalign = 0;

        var grid = new Grid ();
        grid.row_spacing = 10;
        grid.column_spacing = 16;

        int row = 0;

        hostname_entry = new Entry ();
        hostname_entry.text = config.hostname;
        hostname_entry.hexpand = true;
        hostname_entry.changed.connect (() => { 
            config.hostname = hostname_entry.text; 
            revalidate (); 
        });
        attach_row (grid, "Hostname", hostname_entry, ref row);

        display_name_entry = new Entry ();
        display_name_entry.placeholder_text = "e.g. Gżegorz Brzęczyszczykiewicz";
        display_name_entry.changed.connect (() => {
            config.display_name = display_name_entry.text;
            if (auto_username) {
                string slug = display_name_entry.text.down ().replace (" ", "_");
                try {
                    var regex = new GLib.Regex("[^a-z0-9_]");
                    slug = regex.replace_literal (slug, slug.length, 0, "");
                } catch (Error e) {}
                username_entry.text = slug;
                auto_username = true; 
            }
            revalidate ();
        });
        attach_row (grid, "Display Name", display_name_entry, ref row);

        username_entry = new Entry ();
        username_entry.text = config.username;
        username_entry.hexpand = true;
        username_entry.changed.connect (() => { 
            if (username_entry.has_focus) {
                auto_username = false;
            }
            config.username = username_entry.text; 
            revalidate (); 
        });
        attach_row (grid, "Username", username_entry, ref row);

        user_pass_entry = new Entry ();
        user_pass_entry.visibility = false;
        user_pass_entry.input_purpose = InputPurpose.PASSWORD;
        user_pass_entry.changed.connect (() => { 
            config.user_pass = user_pass_entry.text; 
            revalidate (); 
        });
        attach_row (grid, "Password", user_pass_entry, ref row);

        user_pass_confirm = new Entry ();
        user_pass_confirm.visibility = false;
        user_pass_confirm.input_purpose = InputPurpose.PASSWORD;
        user_pass_confirm.changed.connect (revalidate);
        attach_row (grid, "Confirm Password", user_pass_confirm, ref row);

        root_pass_entry = new Entry ();
        root_pass_entry.visibility = false;
        root_pass_entry.input_purpose = InputPurpose.PASSWORD;
        root_pass_entry.placeholder_text = "Leave empty to disable";
        root_pass_entry.changed.connect (() => { 
            config.root_pass = root_pass_entry.text; 
            revalidate ();
        });
        attach_row (grid, "Root Password", root_pass_entry, ref row);

        long mem_mb = get_total_ram_mb ();
        swap_combo = new ComboBoxText ();
        swap_combo.append ("0", "None");
        swap_combo.append ("512", "512 MB");
        swap_combo.append ("1024", "1 GB");
        swap_combo.append ("2048", "2 GB");
        swap_combo.append ("4096", "4 GB");
        swap_combo.append (mem_mb.to_string (), @"Auto ($(mem_mb) MB)");
        swap_combo.set_active_id (mem_mb.to_string ());
        swap_combo.hexpand = true;
        swap_combo.changed.connect (() => {
            config.swap_size = int.parse (swap_combo.get_active_id ());
        });
        attach_row (grid, "Swapfile", swap_combo, ref row);

        validation_label = new Label ("");
        validation_label.get_style_context ().add_class ("warning-text");
        validation_label.halign = Align.START;

        this.pack_start (header, false, false, 0);
        this.pack_start (desc, false, false, 0);
        this.pack_start (grid, false, false, 0);
        this.pack_start (validation_label, false, false, 0);
    }

    private long get_total_ram_mb () {
        try {
            string contents;
            GLib.FileUtils.get_contents ("/proc/meminfo", out contents);
            foreach (string line in contents.split ("\n")) {
                if (line.has_prefix ("MemTotal:")) {
                    var parts = line.split (" ");
                    foreach (string p in parts) {
                        if (p != "" && p != "MemTotal:") {
                            return long.parse (p) / 1024;
                        }
                    }
                }
            }
        } catch (Error e) {}
        return 2048;
    }

    private void attach_row (Grid grid, string label, Widget widget, ref int row) {
        var l = new Label (label);
        l.get_style_context ().add_class ("form-label");
        l.xalign = 1;
        grid.attach (l, 0, row, 1, 1);
        grid.attach (widget, 1, row, 1, 1);
        row++;
    }

    private void revalidate () {
        validation_changed (is_valid ());
    }

    public bool is_valid () {
        if (hostname_entry.text.strip () == "") {
            validation_label.label = "Hostname cannot be empty.";
            return false;
        }
        if (username_entry.text.strip () == "") {
            validation_label.label = "Username cannot be empty.";
            return false;
        }
        if (user_pass_entry.text == "") {
            validation_label.label = "Password cannot be empty.";
            return false;
        }
        if (user_pass_entry.text != user_pass_confirm.text) {
            validation_label.label = "Passwords do not match.";
            return false;
        }
        
        validation_label.label = "";
        return true;
    }
}