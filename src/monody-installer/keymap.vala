using Gtk;

public class KeymapPage : Box {
    private InstallConfig config;
    private Gtk.ListStore layout_store;
    private Gtk.ListStore variant_store;
    private TreeView layout_view;
    private TreeView variant_view;
    private Gtk.ListStore filtered_variant_store;
    private Entry test_entry;

    public KeymapPage (InstallConfig config) {
        this.config = config;
        this.orientation = Orientation.VERTICAL;
        this.spacing = 12;
        this.margin = 30;

        var header = new Label ("Keyboard Layout");
        header.get_style_context ().add_class ("page-header");
        header.xalign = 0;

        var desc = new Label ("Select the keyboard layout for your system.");
        desc.get_style_context ().add_class ("page-desc");
        desc.xalign = 0;

        layout_store = new Gtk.ListStore (2, typeof (string), typeof (string));
        variant_store = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (string));
        filtered_variant_store = new Gtk.ListStore (2, typeof (string), typeof (string));

        load_keymaps ();

        layout_view = new TreeView.with_model (layout_store);
        layout_view.headers_visible = false;
        layout_view.enable_search = true;
        layout_view.set_search_column (1);
        layout_view.set_search_equal_func ((model, column, key, iter) => {
            GLib.Value val;
            model.get_value (iter, column, out val);
            string text = val.get_string ();
            if (text == null) return true;
            return !text.down ().contains (key.down ());
        });
        var layout_renderer = new CellRendererText ();
        var layout_column = new TreeViewColumn.with_attributes ("Layout", layout_renderer, "text", 1);
        layout_view.append_column (layout_column);

        variant_view = new TreeView.with_model (filtered_variant_store);
        variant_view.headers_visible = false;
        variant_view.enable_search = true;
        variant_view.set_search_column (1);
        variant_view.set_search_equal_func ((model, column, key, iter) => {
            GLib.Value val;
            model.get_value (iter, column, out val);
            string text = val.get_string ();
            if (text == null) return true;
            return !text.down ().contains (key.down ());
        });
        var variant_renderer = new CellRendererText ();
        var variant_column = new TreeViewColumn.with_attributes ("Variant", variant_renderer, "text", 1);
        variant_view.append_column (variant_column);

        var layout_scroll = new ScrolledWindow (null, null);
        layout_scroll.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
        layout_scroll.add (layout_view);

        var variant_scroll = new ScrolledWindow (null, null);
        variant_scroll.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
        variant_scroll.add (variant_view);

        var paned = new Paned (Orientation.HORIZONTAL);
        paned.pack1 (layout_scroll, true, false);
        paned.pack2 (variant_scroll, true, false);
        paned.position = 350;
        paned.vexpand = true;

        test_entry = new Entry ();
        test_entry.placeholder_text = "Type here to test your keyboard";
        test_entry.margin_top = 10;

        layout_view.get_selection ().changed.connect (on_layout_selected);
        variant_view.get_selection ().changed.connect (on_variant_selected);

        this.pack_start (header, false, false, 0);
        this.pack_start (desc, false, false, 0);
        this.pack_start (paned, true, true, 0);
        this.pack_start (test_entry, false, false, 0);

        TreeIter iter;
        if (layout_store.get_iter_first (out iter)) {
            layout_view.get_selection ().select_iter (iter);
        }
    }

    private void load_keymaps () {
        try {
            var file = GLib.File.new_for_path ("/usr/share/X11/xkb/rules/base.lst");
            if (!file.query_exists ()) return;
            
            var dis = new DataInputStream (file.read ());
            string line;
            string current_section = "";

            TreeIter iter;
            while ((line = dis.read_line (null)) != null) {
                if (line.has_prefix ("! ")) {
                    current_section = line.substring (2).strip ();
                    continue;
                }
                string tline = line.strip ();
                if (tline == "") continue;

                if (current_section == "layout") {
                    var parts = tline.split (" ", 2);
                    if (parts.length >= 2) {
                        string code = parts[0].strip ();
                        string desc = parts[1].strip ();
                        layout_store.append (out iter);
                        layout_store.set (iter, 0, code, 1, desc);
                    }
                } else if (current_section == "variant") {
                    var parts = tline.split (" ", 2);
                    if (parts.length >= 2) {
                        string code = parts[0].strip ();
                        string rest = parts[1].strip ();
                        var subparts = rest.split (":", 2);
                        if (subparts.length >= 2) {
                            string layout_code = subparts[0].strip ();
                            string desc = subparts[1].strip ();
                            variant_store.append (out iter);
                            variant_store.set (iter, 0, code, 1, desc, 2, layout_code);
                        }
                    }
                }
            }
        } catch (Error e) {}
    }

    private void on_layout_selected () {
        TreeIter iter;
        TreeModel model;
        if (layout_view.get_selection ().get_selected (out model, out iter)) {
            GLib.Value val_code, val_desc;
            model.get_value (iter, 0, out val_code);
            model.get_value (iter, 1, out val_desc);
            
            string layout_code = val_code.get_string ();
            string layout_desc = val_desc.get_string ();
            
            config.keymap = layout_code;

            filtered_variant_store.clear ();
            TreeIter v_iter;
            
            // Add default variant
            filtered_variant_store.append (out v_iter);
            filtered_variant_store.set (v_iter, 0, "", 1, layout_desc + " (Default)");

            TreeIter search_iter;
            if (variant_store.get_iter_first (out search_iter)) {
                do {
                    GLib.Value v_code, v_desc, v_parent_code;
                    variant_store.get_value (search_iter, 0, out v_code);
                    variant_store.get_value (search_iter, 1, out v_desc);
                    variant_store.get_value (search_iter, 2, out v_parent_code);

                    if (v_parent_code.get_string () == layout_code) {
                        filtered_variant_store.append (out v_iter);
                        filtered_variant_store.set (v_iter, 0, v_code.get_string (), 1, v_desc.get_string ());
                    }
                } while (variant_store.iter_next (ref search_iter));
            }

            if (filtered_variant_store.get_iter_first (out v_iter)) {
                variant_view.get_selection ().select_iter (v_iter);
            }
        }
    }

    private void on_variant_selected () {
        TreeIter iter;
        TreeModel model;
        if (variant_view.get_selection ().get_selected (out model, out iter)) {
            GLib.Value val_code;
            model.get_value (iter, 0, out val_code);
            string variant_code = val_code.get_string ();
            
            TreeIter l_iter;
            TreeModel l_model;
            if (layout_view.get_selection ().get_selected (out l_model, out l_iter)) {
                GLib.Value l_val_code;
                l_model.get_value (l_iter, 0, out l_val_code);
                string l_code = l_val_code.get_string ();

                if (variant_code != "") {
                    config.keymap = l_code + "-" + variant_code;
                    try {
                        GLib.Process.spawn_command_line_async ("setxkbmap -layout " + l_code + " -variant " + variant_code);
                    } catch (Error e) {}
                } else {
                    config.keymap = l_code;
                    try {
                        GLib.Process.spawn_command_line_async ("setxkbmap -layout " + l_code);
                    } catch (Error e) {}
                }
            }
        }
    }
}