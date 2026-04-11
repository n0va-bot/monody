using Gtk;
using Vte;

public class UpdaterWindow : Gtk.Window {

    private bool running = false;
    private Gtk.Stack stack;
    private Gtk.Button refresh_btn;
    private Gtk.Spinner spin;
    private Gtk.Label status;
    private Vte.Terminal term;

    public UpdaterWindow () {
        this.set_default_size (820, 540);
        this.window_position = Gtk.WindowPosition.CENTER;
        this.destroy.connect (Gtk.main_quit);

        var hb = new Gtk.HeaderBar ();
        hb.title = "System Update";
        hb.subtitle = "Monody OS";
        hb.show_close_button = true;
        this.set_titlebar (hb);

        status = new Gtk.Label ("");
        spin = new Gtk.Spinner ();
        
        var header_controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        header_controls.pack_end (status, false, false, 0);
        header_controls.pack_end (spin, false, false, 0);
        hb.pack_end (header_controls);

        refresh_btn = new Gtk.Button.with_label ("Run Again");
        refresh_btn.get_style_context ().add_class ("suggested-action");
        refresh_btn.no_show_all = true;
        hb.pack_start (refresh_btn);

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

        var start_btn = new Gtk.Button.with_label ("Run System Update");
        start_btn.get_style_context ().add_class ("suggested-action");
        start_btn.get_style_context ().add_class ("big-start-btn");
        start_box.pack_start (start_btn, false, false, 0);

        var term_sw = new Gtk.ScrolledWindow (null, null);
        term_sw.add (term);

        stack = new Gtk.Stack ();
        stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        stack.add_named (start_box, "start");
        stack.add_named (term_sw, "term");
        this.add (stack);

        term.child_exited.connect ((ws) => {
            running = false;
            spin.stop ();
            refresh_btn.show ();

            if (ws == 0) {
                status.set_markup ("<b>✓ Update Complete</b>");
                status.get_style_context ().remove_class ("error-st");
                status.get_style_context ().add_class ("success-st");
            } else {
                status.set_markup ("<b>✗ Update Failed</b>");
                status.get_style_context ().remove_class ("success-st");
                status.get_style_context ().add_class ("error-st");
            }
        });

        start_btn.clicked.connect (trigger_update);
        refresh_btn.clicked.connect (trigger_update);
        
        refresh_btn.hide (); 
    }

    private void trigger_update () {
        if (running) return;
        running = true;
        
        stack.visible_child_name = "term";
        refresh_btn.hide ();
        spin.show ();
        spin.start ();
        
        status.set_text ("Updating…");
        status.get_style_context ().remove_class ("success-st");
        status.get_style_context ().remove_class ("error-st");
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
                    spin.stop ();
                    refresh_btn.show ();
                    status.set_markup ("<b>✗ Launch Failed</b>");
                    status.get_style_context ().add_class ("error-st");
                }
            }
        );
    }
}

int main (string[] args) {
    Gtk.init (ref args);

    string css_text = """
        .success-st { color: #50fa7b; font-weight: bold; }
        .error-st   { color: #ff5555; font-weight: bold; }
        .updater-terminal { padding: 4px; }
        .big-start-btn { 
            font-size: 24px; 
            font-weight: bold; 
            min-height: 80px; 
            min-width: 280px; 
            border-radius: 12px;
        }
    """;
    var css = new Gtk.CssProvider ();
    try {
        css.load_from_data (css_text);
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    } catch (Error e) {}

    var win = new UpdaterWindow ();
    win.show_all ();
    Gtk.main ();
    return 0;
}
