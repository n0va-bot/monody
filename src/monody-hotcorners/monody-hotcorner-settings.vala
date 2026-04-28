using Gtk;
using GLib;


private struct CornerWidgets {
    public Gtk.ComboBoxText action_combo;
    public Gtk.Entry command_entry;
    public Gtk.Revealer command_revealer;
    public string xfconf_path;
}

public class HotcornerSettings : Object {

    private Xfconf.Channel channel;
    private CornerWidgets[] corner_widgets;
    private Gtk.Scale sensitivity_scale;
    private Gtk.Scale pressure_scale;

    private const string CSS = """
        .corner-frame {
            border: 1px solid alpha(@theme_fg_color, 0.15);
            border-radius: 8px;
            padding: 12px;
            background: alpha(@theme_bg_color, 0.5);
        }
        .corner-label {
            font-weight: bold;
            font-size: 11px;
            opacity: 0.7;
        }
        .section-title {
            font-weight: bold;
            font-size: 13px;
        }
    """;

    private string[] corner_names = {
        "Top Left", "Top Right",
        "Bottom Left", "Bottom Right"
    };

    private string[] corner_paths = {
        "top-left", "top-right",
        "bottom-left", "bottom-right"
    };

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

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 18);
        main_box.margin = 16;

        var preview_label = new Gtk.Label ("Screen Corners");
        preview_label.get_style_context ().add_class ("section-title");
        preview_label.halign = Gtk.Align.START;
        main_box.pack_start (preview_label, false, false, 0);

        var preview_desc = new Gtk.Label ("Configure an action for each corner of your screen.");
        preview_desc.halign = Gtk.Align.START;
        preview_desc.get_style_context ().add_class ("dim-label");
        main_box.pack_start (preview_desc, false, false, 0);

        corner_widgets = new CornerWidgets[4];
        var corner_grid = new Gtk.Grid ();
        corner_grid.column_spacing = 12;
        corner_grid.row_spacing = 12;
        corner_grid.column_homogeneous = true;

        int[,] positions = { {0, 0}, {1, 0}, {0, 1}, {1, 1} };

        for (int i = 0; i < 4; i++) {
            var frame = build_corner_widget (i);
            corner_grid.attach (frame, positions[i,0], positions[i,1], 1, 1);
        }

        main_box.pack_start (corner_grid, false, false, 0);

        var sens_sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        main_box.pack_start (sens_sep, false, false, 4);

        var sens_label = new Gtk.Label ("Trigger Sensitivity");
        sens_label.get_style_context ().add_class ("section-title");
        sens_label.halign = Gtk.Align.START;
        main_box.pack_start (sens_label, false, false, 0);

        var sens_grid = new Gtk.Grid ();
        sens_grid.column_spacing = 16;
        sens_grid.row_spacing = 10;

        var sl = new Gtk.Label ("Speed Sensitivity");
        sl.halign = Gtk.Align.END;
        sens_grid.attach (sl, 0, 0, 1, 1);

        sensitivity_scale = new Gtk.Scale.with_range (
            Gtk.Orientation.HORIZONTAL, 1, 10, 1);
        sensitivity_scale.hexpand = true;
        sensitivity_scale.set_value (
            channel.get_int ("/hotcorners/sensitivity", 5));
        sensitivity_scale.add_mark (3, Gtk.PositionType.BOTTOM, "Low");
        sensitivity_scale.add_mark (7, Gtk.PositionType.BOTTOM, "High");
        sensitivity_scale.value_changed.connect (() => {
            channel.set_int ("/hotcorners/sensitivity",
                             (int) sensitivity_scale.get_value ());
        });
        sens_grid.attach (sensitivity_scale, 1, 0, 1, 1);

        var pl = new Gtk.Label ("Pressure Duration");
        pl.halign = Gtk.Align.END;
        sens_grid.attach (pl, 0, 1, 1, 1);

        pressure_scale = new Gtk.Scale.with_range (
            Gtk.Orientation.HORIZONTAL, 50, 1000, 50);
        pressure_scale.hexpand = true;
        pressure_scale.set_value (
            channel.get_int ("/hotcorners/pressure-duration", 300));
        pressure_scale.add_mark (200, Gtk.PositionType.BOTTOM, "Fast");
        pressure_scale.add_mark (600, Gtk.PositionType.BOTTOM, "Slow");
        pressure_scale.value_changed.connect (() => {
            channel.set_int ("/hotcorners/pressure-duration",
                             (int) pressure_scale.get_value ());
        });
        sens_grid.attach (pressure_scale, 1, 1, 1, 1);

        var punit = new Gtk.Label ("ms");
        punit.get_style_context ().add_class ("dim-label");
        sens_grid.attach (punit, 2, 1, 1, 1);

        main_box.pack_start (sens_grid, false, false, 0);

        return main_box;
    }

    private Gtk.Widget build_corner_widget (int index) {
        var frame = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        frame.get_style_context ().add_class ("corner-frame");

        var header = new Gtk.Label (corner_names[index]);
        header.get_style_context ().add_class ("corner-label");
        header.halign = Gtk.Align.START;
        frame.pack_start (header, false, false, 0);

        var combo = new Gtk.ComboBoxText ();
        combo.append ("none", "None");
        combo.append ("xfdashboard", "Dashboard");
        combo.append ("show-desktop", "Show Desktop");
        combo.append ("custom-command", "Custom Command…");

        string path = "/hotcorners/" + corner_paths[index];
        string current_action = channel.get_string (
            path + "/action", "none");
        combo.set_active_id (current_action);

        frame.pack_start (combo, false, false, 0);

        var cmd_revealer = new Gtk.Revealer ();
        cmd_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;

        var cmd_entry = new Gtk.Entry ();
        cmd_entry.placeholder_text = "Enter command…";
        cmd_entry.text = channel.get_string (path + "/command", "");
        cmd_entry.changed.connect (() => {
            channel.set_string (path + "/command", cmd_entry.text);
        });
        cmd_revealer.add (cmd_entry);
        cmd_revealer.reveal_child = (current_action == "custom-command");

        frame.pack_start (cmd_revealer, false, false, 0);

        combo.changed.connect (() => {
            string id = combo.get_active_id ();
            channel.set_string (path + "/action", id);
            cmd_revealer.reveal_child = (id == "custom-command");
        });

        corner_widgets[index] = CornerWidgets () {
            action_combo = combo,
            command_entry = cmd_entry,
            command_revealer = cmd_revealer,
            xfconf_path = path
        };

        return frame;
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

    var settings = new HotcornerSettings ();
    var widget = settings.build_ui ();

    if (socket_id != 0) {
        var plug = new Gtk.Plug ((X.Window) socket_id);
        plug.destroy.connect (Gtk.main_quit);
        plug.add (widget);
        plug.show_all ();
    } else {
        var window = new Gtk.Window ();
        window.title = "Hotcorners";
        window.set_default_size (520, 480);
        window.window_position = Gtk.WindowPosition.CENTER;
        window.destroy.connect (Gtk.main_quit);

        var sw = new Gtk.ScrolledWindow (null, null);
        sw.hscrollbar_policy = Gtk.PolicyType.NEVER;
        sw.add (widget);
        window.add (sw);
        window.show_all ();
    }

    Gtk.main ();
    return 0;
}