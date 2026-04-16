using Gtk;
using Vte;

public class UpdaterWindow : Gtk.Box {

    private bool running = false;
    private bool update_succeeded = false;
    private bool auto_start = false;
    private bool auto_finish = false;
    private Gtk.Stack stack;
    private Gtk.Button start_btn;
    private Vte.Terminal term;
    private Gtk.Button finish_btn;
    private Gtk.Label finish_title;
    private Gtk.Label finish_msg;
    private Gtk.Image finish_icon;

    public UpdaterWindow (bool auto_start, bool auto_finish) {
        Object (orientation: Gtk.Orientation.VERTICAL);
        this.auto_start = auto_start;
        this.auto_finish = auto_finish;

        term = new Vte.Terminal ();
        term.set_scroll_on_output (true);
        term.set_scrollback_lines (10000);
        term.get_style_context ().add_class ("updater-terminal");

        var bg = Gdk.RGBA ();  bg.parse ("#0e0e1a");
        var fg = Gdk.RGBA ();  fg.parse ("#e0def4");
        term.set_color_background (bg);
        term.set_color_foreground (fg);

        Gdk.RGBA[] pal = new Gdk.RGBA[16];
        string[] cs = {
            "#232336", "#ff5555", "#50fa7b", "#f1fa8c",
            "#bd93f9", "#ff79c6", "#8be9fd", "#f8f8f2",
            "#6272a4", "#ff6e6e", "#69ff94", "#ffffa5",
            "#d6acff", "#ff92df", "#a4ffff", "#ffffff"
        };
        for (int i = 0; i < 16; i++) {
            pal[i] = Gdk.RGBA ();
            pal[i].parse (cs[i]);
        }
        term.set_colors (fg, bg, pal);

        var font = Pango.FontDescription.from_string ("Monospace 11");
        term.set_font (font);

        var start_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 16);
        start_box.halign = Gtk.Align.CENTER;
        start_box.valign = Gtk.Align.CENTER;

        var start_icon = new Gtk.Image.from_icon_name ("system-software-update-symbolic", Gtk.IconSize.DIALOG);
        start_icon.pixel_size = 96;
        start_box.pack_start (start_icon, false, false, 0);

        start_btn = new Gtk.Button.with_label ("Run System Update");
        start_btn.get_style_context ().add_class ("suggested-action");
        start_btn.get_style_context ().add_class ("big-start-btn");
        start_box.pack_start (start_btn, false, false, 0);

        var term_sw = new Gtk.ScrolledWindow (null, null);
        term_sw.add (term);

        var finish_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 16);
        finish_box.halign = Gtk.Align.CENTER;
        finish_box.valign = Gtk.Align.CENTER;

        finish_icon = new Gtk.Image ();
        finish_icon.pixel_size = 96;
        finish_box.pack_start (finish_icon, false, false, 0);

        finish_title = new Gtk.Label ("");
        finish_title.get_style_context ().add_class ("finish-title");
        finish_box.pack_start (finish_title, false, false, 0);

        finish_msg = new Gtk.Label ("");
        finish_msg.get_style_context ().add_class ("finish-msg");
        finish_box.pack_start (finish_msg, false, false, 0);

        finish_btn = new Gtk.Button.with_label ("Done");
        finish_btn.get_style_context ().add_class ("suggested-action");
        finish_btn.get_style_context ().add_class ("big-start-btn");
        finish_box.pack_start (finish_btn, false, false, 0);

        finish_btn.clicked.connect (() => {
            var toplevel = this.get_toplevel () as Gtk.Window;
            if (toplevel != null) toplevel.destroy ();
            else Gtk.main_quit ();
        });

        stack = new Gtk.Stack ();
        stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        stack.add_named (start_box, "start");
        stack.add_named (term_sw, "term");
        stack.add_named (finish_box, "finish");
        this.pack_start (stack, true, true, 0);

        if (auto_start) {
            stack.visible_child_name = "term";
            GLib.Idle.add (() => {
                trigger_update ();
                return false;
            });
        }

        term.child_exited.connect ((ws) => {
            running = false;

            if (ws == 0) {
                update_succeeded = true;
                finish_icon.set_from_icon_name ("object-select-symbolic", Gtk.IconSize.DIALOG);
                finish_title.set_markup ("<span size='32' weight='bold'>Update Complete</span>");
                finish_msg.set_text ("Your system is now up to date.");
                finish_title.get_style_context ().remove_class ("fail-title");
                finish_title.get_style_context ().add_class ("success-title");
            } else {
                update_succeeded = false;
                finish_icon.set_from_icon_name ("dialog-error-symbolic", Gtk.IconSize.DIALOG);
                finish_title.set_markup ("<span size='32' weight='bold'>Update Failed</span>");
                finish_msg.set_text ("Something went wrong during the update.");
                finish_title.get_style_context ().remove_class ("success-title");
                finish_title.get_style_context ().add_class ("fail-title");
            }

            if (auto_finish) {
                var toplevel = this.get_toplevel () as Gtk.Window;
                if (toplevel != null) toplevel.destroy ();
                else Gtk.main_quit ();
            } else {
                stack.visible_child_name = "finish";
            }
        });

        start_btn.clicked.connect (trigger_update);
    }

    private void trigger_update () {
        if (running) return;
        running = true;
        
        stack.visible_child_name = "term";
        term.reset (true, true);

        string[] argv = { "/bin/bash", "-c", "topgrade -y" };
        term.spawn_async (
            Vte.PtyFlags.DEFAULT,
            null,
            argv,
            null,
            GLib.SpawnFlags.SEARCH_PATH,
            null,
            -1,
            null,
            (t, pid, err) => {
                if (err != null) {
                    running = false;
                }
            }
        );
    }
}

int main (string[] args) {
    bool auto_start = false;
    bool auto_finish = false;
    bool show_help = false;
    string? socket_id_str = null;

    var opt_context = new GLib.OptionContext ();
    opt_context.add_group (Gtk.get_option_group (true));

    var options = new GLib.OptionEntry[4];
    options[0].long_name = "help";
    options[0].short_name = 'h';
    options[0].arg = GLib.OptionArg.NONE;
    options[0].arg_data = &show_help;
    options[0].description = "Show help";

    options[1].long_name = "start";
    options[1].short_name = 0;
    options[1].arg = GLib.OptionArg.NONE;
    options[1].arg_data = &auto_start;
    options[1].description = "Skip start screen";

    options[2].long_name = "finish";
    options[2].short_name = 0;
    options[2].arg = GLib.OptionArg.NONE;
    options[2].arg_data = &auto_finish;
    options[2].description = "Close window when finished";

    options[3].long_name = "socket-id";
    options[3].short_name = 's';
    options[3].arg = GLib.OptionArg.STRING;
    options[3].arg_data = &socket_id_str;
    options[3].description = "Settings Manager socket ID";

    opt_context.add_main_entries (options, null);

    opt_context.set_ignore_unknown_options (true);
    try {
        opt_context.parse (ref args);
    } catch (Error e) {
        print ("Error: %s\n", e.message);
        return 1;
    }

    if (show_help) {
        print ("Usage: monody-updater [OPTIONS]\n");
        print ("  -h, --help      Show this help\n");
        print ("  --start         Start update on launch, skip start screen\n");
        print ("  --finish    Close window when finished\n");
        return 0;
    }

    Gtk.init (ref args);

    long socket_id = 0;
    if (socket_id_str != null) {
        if (socket_id_str.has_prefix ("=")) {
            socket_id = long.parse (socket_id_str.substring (1));
        } else {
            socket_id = long.parse (socket_id_str);
        }
    }
    
    for (int i = 0; i < args.length; i++) {
        if (args[i] == "--socket-id" && i + 1 < args.length) {
            socket_id = long.parse (args[i + 1]);
        } else if (args[i].has_prefix ("--socket-id=")) {
            socket_id = long.parse (args[i].substring (12));
        }
    }

    string css_text = """
        .updater-terminal { padding: 4px; }
        .big-start-btn { 
            font-size: 24px; 
            font-weight: bold; 
            min-height: 80px; 
            min-width: 280px; 
            border-radius: 12px;
        }
        .success-title { color: #50fa7b; }
        .fail-title { color: #ff5555; }
        .finish-msg { color: #a0a0b0; font-size: 14px; }
    """;
    var css = new Gtk.CssProvider ();
    try {
        css.load_from_data (css_text);
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    } catch (Error e) {}

    var win = new UpdaterWindow (auto_start, auto_finish);
    win.vexpand = true;
    win.hexpand = true;

    if (socket_id != 0) {
        var plug = new Gtk.Plug ((X.Window) socket_id);
        plug.destroy.connect (Gtk.main_quit);
        plug.add (win);
        plug.show_all ();
    } else {
        var window = new Gtk.Window ();
        window.title = "System Update";
        window.set_default_size (820, 540);
        window.window_position = Gtk.WindowPosition.CENTER;
        window.destroy.connect (Gtk.main_quit);

        var hb = new Gtk.HeaderBar ();
        hb.title = "System Update";
        hb.subtitle = "Monody OS";
        hb.show_close_button = true;
        window.set_titlebar (hb);

        window.add (win);
        window.show_all ();
    }

    Gtk.main ();
    return 0;
}