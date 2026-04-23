using Gtk;
using GLib;


public class FileSearchSettings : Object {

    private Xfconf.Channel channel;
    private Gtk.ListStore dir_store;
    private Gtk.TreeView dir_tree;

    private string[] default_dirs = {
        "Documents", "Downloads", "Pictures",
        "Music", "Videos", "Desktop"
    };

    private const string CSS = """
        .section-title {
            font-weight: bold;
            font-size: 13px;
        }
        .dir-frame {
            border: 1px solid alpha(@theme_fg_color, 0.15);
            border-radius: 6px;
        }
    """;

    public Gtk.Widget build_ui () {
        try {
            Xfconf.init ();
        } catch (Error e) {
            stderr.printf ("xfconf init failed: %s\n", e.message);
        }

        channel = new Xfconf.Channel ("monody");

        var prov = new Gtk.CssProvider ();
        try {
            prov.load_from_data (CSS);
            Gtk.StyleContext.add_provider_for_screen (
                Gdk.Screen.get_default (), prov,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {}

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 14);
        main_box.margin = 16;

        var dir_label = new Gtk.Label ("Search Directories");
        dir_label.get_style_context ().add_class ("section-title");
        dir_label.halign = Gtk.Align.START;
        main_box.pack_start (dir_label, false, false, 0);

        var dir_desc = new Gtk.Label (
            "Files inside these directories (relative to Home) will be included in search results.");
        dir_desc.halign = Gtk.Align.START;
        dir_desc.get_style_context ().add_class ("dim-label");
        dir_desc.wrap = true;
        dir_desc.xalign = 0;
        main_box.pack_start (dir_desc, false, false, 0);

        dir_store = new Gtk.ListStore (1, typeof (string));
        load_directories ();

        dir_tree = new Gtk.TreeView.with_model (dir_store);
        dir_tree.headers_visible = false;
        var col = new Gtk.TreeViewColumn ();
        var cell = new Gtk.CellRendererText ();
        col.pack_start (cell, true);
        col.add_attribute (cell, "text", 0);
        dir_tree.append_column (col);
        dir_tree.get_selection ().mode = Gtk.SelectionMode.SINGLE;

        var sw = new Gtk.ScrolledWindow (null, null);
        sw.hscrollbar_policy = Gtk.PolicyType.NEVER;
        sw.min_content_height = 150;
        sw.get_style_context ().add_class ("dir-frame");
        sw.add (dir_tree);
        main_box.pack_start (sw, true, true, 0);

        var btn_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        btn_box.halign = Gtk.Align.START;

        var add_btn = new Gtk.Button.from_icon_name (
            "list-add-symbolic", Gtk.IconSize.BUTTON);
        add_btn.tooltip_text = "Add search directory";
        add_btn.clicked.connect (on_add_dir);
        btn_box.pack_start (add_btn, false, false, 0);

        var remove_btn = new Gtk.Button.from_icon_name (
            "list-remove-symbolic", Gtk.IconSize.BUTTON);
        remove_btn.tooltip_text = "Remove selected directory";
        remove_btn.clicked.connect (on_remove_dir);
        btn_box.pack_start (remove_btn, false, false, 0);

        var reset_btn = new Gtk.Button.with_label ("Reset to Defaults");
        reset_btn.halign = Gtk.Align.END;
        reset_btn.hexpand = true;
        reset_btn.clicked.connect (on_reset_dirs);
        btn_box.pack_end (reset_btn, false, false, 0);

        main_box.pack_start (btn_box, false, false, 0);

        var opt_sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        main_box.pack_start (opt_sep, false, false, 4);

        var opt_label = new Gtk.Label ("Search Options");
        opt_label.get_style_context ().add_class ("section-title");
        opt_label.halign = Gtk.Align.START;
        main_box.pack_start (opt_label, false, false, 0);

        var opt_grid = new Gtk.Grid ();
        opt_grid.column_spacing = 16;
        opt_grid.row_spacing = 10;

        var depth_label = new Gtk.Label ("Max Search Depth");
        depth_label.halign = Gtk.Align.END;
        opt_grid.attach (depth_label, 0, 0, 1, 1);

        var depth_scale = new Gtk.Scale.with_range (
            Gtk.Orientation.HORIZONTAL, 1, 8, 1);
        depth_scale.hexpand = true;
        depth_scale.set_value (
            channel.get_int ("/file-search/max-depth", 3));
        depth_scale.add_mark (3, Gtk.PositionType.BOTTOM, "Default");
        depth_scale.value_changed.connect (() => {
            channel.set_int ("/file-search/max-depth",
                             (int) depth_scale.get_value ());
        });
        opt_grid.attach (depth_scale, 1, 0, 1, 1);

        var results_label = new Gtk.Label ("Max Results");
        results_label.halign = Gtk.Align.END;
        opt_grid.attach (results_label, 0, 1, 1, 1);

        var results_scale = new Gtk.Scale.with_range (
            Gtk.Orientation.HORIZONTAL, 5, 30, 5);
        results_scale.hexpand = true;
        results_scale.set_value (
            channel.get_int ("/file-search/max-results", 10));
        results_scale.value_changed.connect (() => {
            channel.set_int ("/file-search/max-results",
                             (int) results_scale.get_value ());
        });
        opt_grid.attach (results_scale, 1, 1, 1, 1);

        var hidden_label = new Gtk.Label ("Search Hidden Files");
        hidden_label.halign = Gtk.Align.END;
        opt_grid.attach (hidden_label, 0, 2, 1, 1);

        var hidden_switch = new Gtk.Switch ();
        hidden_switch.halign = Gtk.Align.START;
        hidden_switch.active = channel.get_bool (
            "/file-search/show-hidden", false);
        hidden_switch.notify["active"].connect (() => {
            channel.set_bool ("/file-search/show-hidden",
                              hidden_switch.active);
        });
        opt_grid.attach (hidden_switch, 1, 2, 1, 1);

        main_box.pack_start (opt_grid, false, false, 0);

        return main_box;
    }

    private void load_directories () {
        dir_store.clear ();
        string dirs_str = channel.get_string (
            "/file-search/directories", "");

        string[] dirs;
        if (dirs_str == "") {
            dirs = default_dirs;
        } else {
            dirs = dirs_str.split (";");
        }

        foreach (string d in dirs) {
            string trimmed = d.strip ();
            if (trimmed != "") {
                Gtk.TreeIter iter;
                dir_store.append (out iter);
                dir_store.set (iter, 0, trimmed);
            }
        }
    }

    private void save_directories () {
        var dirs = new GenericArray<string> ();
        Gtk.TreeIter iter;
        if (dir_store.get_iter_first (out iter)) {
            do {
                string val;
                dir_store.get (iter, 0, out val);
                dirs.add (val);
            } while (dir_store.iter_next (ref iter));
        }

        var sb = new StringBuilder ();
        for (int i = 0; i < dirs.length; i++) {
            if (i > 0) sb.append (";");
            sb.append (dirs[i]);
        }
        channel.set_string ("/file-search/directories", sb.str);
    }

    private void on_add_dir () {
        var parent = dir_tree.get_toplevel () as Gtk.Window;
        var dialog = new Gtk.Dialog.with_buttons (
            "Add Search Directory", parent,
            Gtk.DialogFlags.MODAL,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Add", Gtk.ResponseType.OK);

        var ok_btn = dialog.get_widget_for_response (Gtk.ResponseType.OK);
        ok_btn.get_style_context ().add_class ("suggested-action");

        var content = dialog.get_content_area ();
        content.margin = 16;
        content.spacing = 10;

        var info = new Gtk.Label (
            "Enter the folder name relative to your Home directory:");
        info.halign = Gtk.Align.START;
        info.wrap = true;
        content.add (info);

        var entry = new Gtk.Entry ();
        entry.placeholder_text = "e.g. Projects";
        entry.activate.connect (() => {
            dialog.response (Gtk.ResponseType.OK);
        });
        content.add (entry);

        dialog.show_all ();
        if (dialog.run () == Gtk.ResponseType.OK) {
            string text = entry.text.strip ();
            if (text != "") {
                Gtk.TreeIter iter;
                dir_store.append (out iter);
                dir_store.set (iter, 0, text);
                save_directories ();
            }
        }
        dialog.destroy ();
    }

    private void on_remove_dir () {
        Gtk.TreeIter iter;
        Gtk.TreeModel model;
        if (dir_tree.get_selection ().get_selected (out model, out iter)) {
            dir_store.remove (ref iter);
            save_directories ();
        }
    }

    private void on_reset_dirs () {
        dir_store.clear ();
        foreach (string d in default_dirs) {
            Gtk.TreeIter iter;
            dir_store.append (out iter);
            dir_store.set (iter, 0, d);
        }
        save_directories ();
    }
}

int main (string[] args) {
    Gtk.init (ref args);

    long socket_id = 0;
    for (int i = 0; i < args.length; i++) {
        if ((args[i] == "--socket-id" || args[i] == "-s") && i + 1 < args.length) {
            socket_id = long.parse (args[i + 1]);
        } else if (args[i].has_prefix ("--socket-id=")) {
            socket_id = long.parse (args[i].substring (12));
        } else if (args[i].has_prefix ("-s=")) {
            socket_id = long.parse (args[i].substring (3));
        }
    }

    var settings = new FileSearchSettings ();
    var widget = settings.build_ui ();

    if (socket_id != 0) {
        var plug = new Gtk.Plug ((X.Window) socket_id);
        plug.destroy.connect (Gtk.main_quit);
        plug.add (widget);
        plug.show_all ();
    } else {
        var window = new Gtk.Window ();
        window.title = "File Search";
        window.set_default_size (480, 500);
        window.window_position = Gtk.WindowPosition.CENTER;
        window.destroy.connect (Gtk.main_quit);

        var hb = new Gtk.HeaderBar ();
        hb.title = "File Search";
        hb.show_close_button = true;
        window.set_titlebar (hb);

        var sw = new Gtk.ScrolledWindow (null, null);
        sw.hscrollbar_policy = Gtk.PolicyType.NEVER;
        sw.add (widget);
        window.add (sw);
        window.show_all ();
    }

    Gtk.main ();
    return 0;
}