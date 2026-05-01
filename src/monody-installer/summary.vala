using Gtk;

public class SummaryPage : Box {
    private InstallConfig config;
    private Gtk.ListStore store;
    private TreeView view;

    public SummaryPage (InstallConfig config) {
        this.config = config;
        this.orientation = Orientation.VERTICAL;
        this.spacing = 12;
        this.margin = 30;

        var header = new Label ("<span font_weight='bold' font_size='large'>Ready to install</span>");
        header.use_markup = true;
        header.xalign = 0;

        var desc = new Label ("Please verify that the following details are correct.");
        desc.xalign = 0;

        store = new Gtk.ListStore (2, typeof (string), typeof (string));
        view = new TreeView.with_model (store);
        view.headers_visible = false;

        var cell_title = new CellRendererText ();
        cell_title.weight = Pango.Weight.BOLD;
        var col_title = new TreeViewColumn.with_attributes ("Setting", cell_title, "text", 0);
        col_title.min_width = 150;
        view.append_column (col_title);

        var cell_val = new CellRendererText ();
        var col_val = new TreeViewColumn.with_attributes ("Value", cell_val, "text", 1);
        view.append_column (col_val);

        var scroll = new ScrolledWindow (null, null);
        scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        scroll.add (view);
        scroll.expand = true;

        this.pack_start (header, false, false, 0);
        this.pack_start (desc, false, false, 0);
        this.pack_start (scroll, true, true, 0);
    }

    public void refresh () {
        store.clear ();

        TreeIter iter;

        store.append (out iter);
        store.set (iter, 0, "Disk:", 1, config.disk + " (" + (config.partition_mode == "auto" ? "Automatic" : "Manual") + ")");

        store.append (out iter);
        store.set (iter, 0, "Timezone:", 1, config.timezone);

        store.append (out iter);
        store.set (iter, 0, "Keyboard:", 1, config.keymap);

        store.append (out iter);
        store.set (iter, 0, "Username:", 1, config.username + " (" + config.display_name + ")");

        store.append (out iter);
        store.set (iter, 0, "Hostname:", 1, config.hostname);

        store.append (out iter);
        store.set (iter, 0, "Root Account:", 1, config.root_pass != "" ? "Enabled" : "Disabled");

        store.append (out iter);
        store.set (iter, 0, "Swap space:", 1, config.swap_size > 0 ? config.swap_size.to_string () + " MB" : "None");
    }
}
