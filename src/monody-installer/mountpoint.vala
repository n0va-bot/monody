using Gtk;

public class MountpointPage : Box {
    private InstallConfig config;
    private TreeView part_view;
    private Gtk.ListStore part_store;

    private const int COL_DEV = 0;
    private const int COL_SIZE = 1;
    private const int COL_FSTYPE = 2;
    private const int COL_MOUNT = 3;
    private const int COL_USE_AS = 4;
    private const int COL_FORMAT = 5;
    private const int COL_ENCRYPT = 6;

    private Gtk.ListStore use_as_model;
    private Gtk.ListStore mount_model;

    public signal void validation_changed ();

    public MountpointPage (InstallConfig config) {
        this.config = config;
        this.orientation = Orientation.VERTICAL;
        this.spacing = 12;
        this.margin = 30;

        var header = new Label ("Assign Mount Points");
        header.get_style_context ().add_class ("page-header");
        header.xalign = 0;

        var desc = new Label ("Select partitions and assign their mount points (e.g. /, /boot, /home).\nClick directly on a cell to edit it.");
        desc.get_style_context ().add_class ("page-desc");
        desc.xalign = 0;

        var launch_btn = new Button.with_label ("Launch GParted");
        launch_btn.get_style_context ().add_class ("suggested-action");
        launch_btn.halign = Align.START;
        launch_btn.clicked.connect (launch_gparted);

        use_as_model = new Gtk.ListStore (1, typeof (string));
        string[] use_items = { "do not use", "ext4", "btrfs", "vfat", "swap" };
        foreach (string s in use_items) {
            TreeIter it;
            use_as_model.append (out it);
            use_as_model.set (it, 0, s);
        }

        mount_model = new Gtk.ListStore (1, typeof (string));
        string[] mount_items = { "", "/", "/boot", "/home", "/var", "/tmp" };
        foreach (string s in mount_items) {
            TreeIter it;
            mount_model.append (out it);
            mount_model.set (it, 0, s);
        }

        part_store = new Gtk.ListStore (7,
            typeof (string), typeof (string), typeof (string),
            typeof (string), typeof (string),
            typeof (bool), typeof (bool));

        part_view = new TreeView.with_model (part_store);
        part_view.set_size_request (-1, 200);
        part_view.get_selection ().set_mode (SelectionMode.SINGLE);

        var dev_rend = new CellRendererText ();
        var dev_col = new TreeViewColumn.with_attributes ("Device", dev_rend, "text", COL_DEV);
        dev_col.min_width = 100;
        part_view.append_column (dev_col);

        var size_rend = new CellRendererText ();
        var size_col = new TreeViewColumn.with_attributes ("Size", size_rend, "text", COL_SIZE);
        size_col.min_width = 60;
        part_view.append_column (size_col);

        var type_rend = new CellRendererText ();
        var type_col = new TreeViewColumn.with_attributes ("Type", type_rend, "text", COL_FSTYPE);
        type_col.min_width = 60;
        part_view.append_column (type_col);

        var use_rend = new CellRendererCombo ();
        use_rend.model = use_as_model;
        use_rend.text_column = 0;
        use_rend.editable = true;
        use_rend.has_entry = false;
        use_rend.changed.connect ((path_str, new_iter) => {
            string new_val;
            use_as_model.get (new_iter, 0, out new_val);
            TreeIter iter;
            part_store.get_iter_from_string (out iter, path_str);
            part_store.set (iter, COL_USE_AS, new_val);

            if (new_val == "swap") {
                part_store.set (iter, COL_MOUNT, "[SWAP]");
            } else if (new_val == "do not use") {
                part_store.set (iter, COL_MOUNT, "", COL_FORMAT, false, COL_ENCRYPT, false);
            }
            update_config_mounts ();
        });
        var use_col = new TreeViewColumn.with_attributes ("Use As", use_rend, "text", COL_USE_AS);
        use_col.min_width = 100;
        part_view.append_column (use_col);

        var mount_rend = new CellRendererCombo ();
        mount_rend.model = mount_model;
        mount_rend.text_column = 0;
        mount_rend.editable = true;
        mount_rend.has_entry = true;
        mount_rend.edited.connect ((path_str, new_text) => {
            TreeIter iter;
            part_store.get_iter_from_string (out iter, path_str);
            part_store.set (iter, COL_MOUNT, new_text);

            if (new_text == "/boot") {
                part_store.set (iter, COL_ENCRYPT, false);
            }
            update_config_mounts ();
        });
        var mount_col = new TreeViewColumn.with_attributes ("Mount Point", mount_rend, "text", COL_MOUNT);
        mount_col.min_width = 100;
        part_view.append_column (mount_col);

        var format_rend = new CellRendererToggle ();
        format_rend.activatable = true;
        format_rend.toggled.connect ((path_str) => {
            TreeIter iter;
            part_store.get_iter_from_string (out iter, path_str);
            bool current;
            part_store.get (iter, COL_FORMAT, out current);
            part_store.set (iter, COL_FORMAT, !current);
            update_config_mounts ();
        });
        var format_col = new TreeViewColumn.with_attributes ("Format", format_rend, "active", COL_FORMAT);
        part_view.append_column (format_col);

        var enc_rend = new CellRendererToggle ();
        enc_rend.activatable = true;
        enc_rend.toggled.connect ((path_str) => {
            TreeIter iter;
            part_store.get_iter_from_string (out iter, path_str);

            string mount_pt;
            part_store.get (iter, COL_MOUNT, out mount_pt);
            if (mount_pt == "/boot") {
                var dlg = new MessageDialog ((Window) this.get_toplevel (), DialogFlags.MODAL,
                    MessageType.WARNING, ButtonsType.OK, "Cannot encrypt the boot partition.");
                dlg.run ();
                dlg.destroy ();
                return;
            }

            bool current;
            part_store.get (iter, COL_ENCRYPT, out current);
            part_store.set (iter, COL_ENCRYPT, !current);
            update_config_mounts ();
        });
        var enc_col = new TreeViewColumn.with_attributes ("Encrypt", enc_rend, "active", COL_ENCRYPT);
        part_view.append_column (enc_col);

        var scroll = new ScrolledWindow (null, null);
        scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        scroll.add (part_view);
        scroll.expand = true;

        var btn_box = new Box (Orientation.HORIZONTAL, 6);
        var reset_btn = new Button.with_label ("Refresh List");
        reset_btn.clicked.connect (refresh_partitions);
        btn_box.pack_start (reset_btn, false, false, 0);

        this.pack_start (header, false, false, 0);
        this.pack_start (desc, false, false, 0);
        this.pack_start (launch_btn, false, false, 0);
        this.pack_start (scroll, true, true, 0);
        this.pack_start (btn_box, false, false, 0);
    }

    public bool is_valid () {
        bool has_root = false;
        bool has_boot = false;

        TreeIter iter;
        if (part_store.get_iter_first (out iter)) {
            do {
                string mount_pt, use_as;
                part_store.get (iter, COL_MOUNT, out mount_pt, COL_USE_AS, out use_as);
                if (use_as != "do not use" && use_as != "") {
                    if (mount_pt == "/") has_root = true;
                    if (mount_pt == "/boot") has_boot = true;
                }
            } while (part_store.iter_next (ref iter));
        }

        if (config.boot_mode == "uefi") {
            return has_root && has_boot;
        }
        return has_root;
    }

    public void launch_gparted () {
        if (config.disk == "") {
            var dlg = new MessageDialog ((Window) this.get_toplevel (), DialogFlags.MODAL, MessageType.WARNING, ButtonsType.OK, "No disk selected.");
            dlg.run ();
            dlg.destroy ();
            return;
        }

        var dlg = new MessageDialog ((Window) this.get_toplevel(), DialogFlags.MODAL, MessageType.INFO, ButtonsType.NONE, "Waiting for GParted to close...");
        dlg.show ();

        Pid pid;
        try {
            GLib.Process.spawn_async (null, {"gparted", config.disk}, null, GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD, null, out pid);
            GLib.ChildWatch.add (pid, (p, status) => {
                GLib.Process.close_pid (p);
                dlg.destroy ();
                refresh_partitions ();
            });
        } catch (Error e) {
            dlg.destroy ();
            warning ("Failed to spawn gparted: %s", e.message);
        }
    }

    private string get_regex_val (string line, string key) {
        try {
            var regex = new Regex (key + "=\"([^\"]*)\"");
            MatchInfo info;
            if (regex.match (line, 0, out info)) {
                return info.fetch (1);
            }
        } catch (Error e) {}
        return "";
    }

    public void refresh_partitions () {
        var saved_mount = new GLib.HashTable<string, string> (str_hash, str_equal);
        var saved_use = new GLib.HashTable<string, string> (str_hash, str_equal);
        var saved_fmt = new GLib.HashTable<string, bool> (str_hash, str_equal);
        var saved_enc = new GLib.HashTable<string, bool> (str_hash, str_equal);

        TreeIter siter;
        if (part_store.get_iter_first (out siter)) {
            do {
                string dev, mount_pt, use_as;
                bool fmt, enc;
                part_store.get (siter, COL_DEV, out dev, COL_MOUNT, out mount_pt,
                    COL_USE_AS, out use_as, COL_FORMAT, out fmt, COL_ENCRYPT, out enc);
                if (use_as != "do not use" && use_as != "") {
                    saved_mount.insert (dev, mount_pt);
                    saved_use.insert (dev, use_as);
                    saved_fmt.insert (dev, fmt);
                    saved_enc.insert (dev, enc);
                }
            } while (part_store.iter_next (ref siter));
        }

        part_store.clear ();
        config.mounts = new GLib.List<PartitionMount> ();

        if (config.disk == "") return;

        try {
            string out_text, err_text;
            int status;
            string[] argv = {"lsblk", "-p", "-P", "-o", "NAME,SIZE,FSTYPE,PARTTYPENAME", config.disk};
            GLib.Process.spawn_sync (null, argv, null, GLib.SpawnFlags.SEARCH_PATH, null, out out_text, out err_text, out status);

            if (status == 0) {
                foreach (string line in out_text.split ("\n")) {
                    if (line.strip () == "") continue;
                    string dev = get_regex_val (line, "NAME");
                    if (dev == config.disk) continue;

                    string size = get_regex_val (line, "SIZE");
                    string fstype = get_regex_val (line, "FSTYPE");
                    if (fstype == "") fstype = get_regex_val (line, "PARTTYPENAME");

                    string mount_pt = "";
                    string use_as = "do not use";
                    bool fmt = false;
                    bool enc = false;

                    if (saved_mount.contains (dev)) {
                        mount_pt = saved_mount.lookup (dev);
                        use_as = saved_use.lookup (dev);
                        fmt = saved_fmt.lookup (dev);
                        enc = saved_enc.lookup (dev);
                    }

                    TreeIter iter;
                    part_store.append (out iter);
                    part_store.set (iter,
                        COL_DEV, dev,
                        COL_SIZE, size,
                        COL_FSTYPE, fstype,
                        COL_MOUNT, mount_pt,
                        COL_USE_AS, use_as,
                        COL_FORMAT, fmt,
                        COL_ENCRYPT, enc
                    );
                }
            }
        } catch (Error e) {
            warning ("Failed to run lsblk: %s", e.message);
        }

        update_config_mounts ();
    }

    private void update_config_mounts () {
        config.mounts = new GLib.List<PartitionMount> ();

        TreeIter iter;
        if (part_store.get_iter_first (out iter)) {
            do {
                string dev, mount_pt, use_as;
                bool format, enc;
                part_store.get (iter, COL_DEV, out dev, COL_MOUNT, out mount_pt,
                    COL_USE_AS, out use_as, COL_FORMAT, out format, COL_ENCRYPT, out enc);

                if (use_as != "do not use" && use_as != "") {
                    config.mounts.append (new PartitionMount (dev, mount_pt, use_as, format, enc));
                }
            } while (part_store.iter_next (ref iter));
        }

        validation_changed ();
    }
}