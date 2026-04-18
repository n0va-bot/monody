using Gtk;

public class DiskPage : Box {
    private InstallConfig config;
    private Gtk.ListStore store;
    private TreeView tree_view;

    public signal void disk_selected ();

    public DiskPage (InstallConfig config) {
        this.config = config;
        this.orientation = Orientation.VERTICAL;
        this.spacing = 12;
        this.margin = 30;

        var header = new Label ("Select Installation Disk");
        header.get_style_context ().add_class ("page-header");
        header.xalign = 0;

        var desc = new Label ("Choose the disk where Monody Linux will be installed.\nAll data on the selected disk will be destroyed.");
        desc.get_style_context ().add_class ("page-desc");
        desc.xalign = 0;

        store = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (string));
        tree_view = new TreeView.with_model (store);
        tree_view.get_style_context ().add_class ("disk-list");
        tree_view.headers_visible = true;
        tree_view.enable_grid_lines = TreeViewGridLines.HORIZONTAL;

        var col_dev = new TreeViewColumn ();
        col_dev.title = "Device";
        col_dev.min_width = 160;
        var cell_dev = new CellRendererText ();
        col_dev.pack_start (cell_dev, true);
        col_dev.add_attribute (cell_dev, "text", 0);
        tree_view.append_column (col_dev);

        var col_size = new TreeViewColumn ();
        col_size.title = "Size";
        col_size.min_width = 100;
        var cell_size = new CellRendererText ();
        col_size.pack_start (cell_size, true);
        col_size.add_attribute (cell_size, "text", 1);
        tree_view.append_column (col_size);

        var col_model = new TreeViewColumn ();
        col_model.title = "Model";
        col_model.expand = true;
        var cell_model = new CellRendererText ();
        col_model.pack_start (cell_model, true);
        col_model.add_attribute (cell_model, "text", 2);
        tree_view.append_column (col_model);

        var scroll = new ScrolledWindow (null, null);
        scroll.add (tree_view);
        scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        scroll.expand = true;
        scroll.get_style_context ().add_class ("disk-scroll");

        tree_view.cursor_changed.connect (() => {
            TreeModel model;
            TreeIter iter;
            if (tree_view.get_selection ().get_selected (out model, out iter)) {
                string disk;
                model.get (iter, 0, out disk);
                this.config.disk = disk;
                disk_selected ();
            }
        });

        this.pack_start (header, false, false, 0);
        this.pack_start (desc, false, false, 0);
        this.pack_start (scroll, true, true, 0);
    }

    public void refresh () {
        store.clear ();
        config.disk = "";
        disk_selected ();
        string output = Utils.run_sync ("lsblk -dlpno NAME,SIZE,MODEL");
        var lines = output.split ("\n");
        foreach (var line in lines) {
            if (line.strip () == "") continue;
            var parts = line.split (" ", 3);
            if (parts.length >= 2) {
                string dev = parts[0].strip ();
                string size = parts[1].strip ();
                string model = parts.length > 2 ? parts[2].strip () : "";

                if (dev.has_prefix ("/dev/loop") || dev.has_prefix ("/dev/ram") ||
                    dev.has_prefix ("/dev/zram") || dev.has_prefix ("/dev/sr")) {
                    continue;
                }

                TreeIter iter;
                store.append (out iter);
                store.set (iter, 0, dev, 1, size, 2, model);
            }
        }
    }
}