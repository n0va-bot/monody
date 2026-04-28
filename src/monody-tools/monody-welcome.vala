using Gtk;
using Vte;
using GLib;

public class WelcomeWindow : Gtk.Window {

    private Gtk.Stack        stack;
    private Vte.Terminal     term;
    private bool             install_running = false;

    private Gtk.CheckButton  opt_bluetooth;
    private Gtk.CheckButton  opt_mediatek_wifi;
    private Gtk.CheckButton  opt_full_firmware;
    private Gtk.CheckButton  opt_printing;
    private Gtk.CheckButton  opt_flatpak;

    private Gtk.Button       action_btn;
    private Gtk.Button       skip_btn;
    private Gtk.Spinner      spinner;
    private Gtk.Label        status_label;
    
    private Gtk.CheckButton  opt_dont_show;

    private const string CSS = """
        .welcome-title {
            font-size: 28px;
            font-weight: bold;
            margin-bottom: 4px;
            color: #bb9af7;
        }
        .section-title {
            font-size: 16px;
            font-weight: bold;
            margin-bottom: 2px;
            color: #7aa2f7;
        }
        .options-list {
            border-radius: 8px;
            border: 1px solid alpha(@borders, 0.4);
            background-color: alpha(@theme_bg_color, 0.5);
        }
        .options-list > row {
            padding: 0;
            border-bottom: 1px solid alpha(@borders, 0.2);
        }
        .options-list > row:last-child {
            border-bottom: none;
        }
        .option-name {
            font-weight: bold;
            color: #e0def4;
        }
        .done-icon {
            color: #50fa7b;
        }
        .success-st { color: #50fa7b; font-weight: bold; }
        .error-st   { color: #ff5555; font-weight: bold; }
        .util-btn {
            font-size: 16px;
            font-weight: bold;
            padding: 12px 24px;
            min-width: 200px;
        }
        .welcome-to {
            font-size: 24px;
            font-weight: 500;
            color: #9aa5ce;
            margin-bottom: -8px;
        }
        .main-title {
            font-family: 'Outfit', 'sans-serif';
            font-size: 84px;
            font-weight: 800;
            letter-spacing: -4px;
            color: #7aa2f7;
            margin-bottom: -10px;
        }
        .main-tagline {
            font-size: 18px;
            color: #9aa5ce;
            margin-bottom: 20px;
            font-weight: 500;
        }
    """;

    public WelcomeWindow () {
        this.title = "Welcome to Monody";
        this.set_default_size (760, 480);
        this.window_position = Gtk.WindowPosition.CENTER;
        this.destroy.connect (on_close);

        var prov = new Gtk.CssProvider ();
        try {
            prov.load_from_data (CSS);
            Gtk.StyleContext.add_provider_for_screen (
                Gdk.Screen.get_default (), prov,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {}

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

        stack = new Gtk.Stack ();
        stack.transition_type     = Gtk.StackTransitionType.CROSSFADE;
        stack.transition_duration = 300;

        stack.add_named (build_welcome_page (), "welcome");
        stack.add_named (build_options_page (), "options");
        stack.add_named (build_utility_page (), "utilities");
        stack.add_named (build_install_page (), "install");
        stack.add_named (build_done_page (),    "done");

        main_box.pack_start (stack, true, true, 0);

        var action_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        action_bar.margin = 12;
        action_bar.halign = Gtk.Align.CENTER;

        action_btn = new Gtk.Button.with_label ("Get Started");
        action_btn.get_style_context ().add_class ("suggested-action");
        action_btn.clicked.connect (on_action_clicked);
        action_bar.pack_start (action_btn, false, false, 0);

        skip_btn = new Gtk.Button.with_label ("Skip Setup");
        skip_btn.no_show_all = true;
        skip_btn.clicked.connect (on_skip_clicked);
        action_bar.pack_start (skip_btn, false, false, 0);

        spinner = new Gtk.Spinner ();
        spinner.no_show_all = true;
        action_bar.pack_end (spinner, false, false, 0);

        status_label = new Gtk.Label ("");
        status_label.no_show_all = true;
        action_bar.pack_end (status_label, false, false, 0);

        main_box.pack_start (action_bar, false, false, 0);

        this.add (main_box);
    }


    private Gtk.Widget build_welcome_page () {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.halign = Gtk.Align.CENTER;
        box.valign = Gtk.Align.CENTER;
        box.margin = 48;

        var welcome_to = new Gtk.Label ("Welcome to");
        welcome_to.get_style_context ().add_class ("welcome-to");
        box.pack_start (welcome_to, false, false, 0);

        var title_label = new Gtk.Label ("monody");
        title_label.get_style_context ().add_class ("main-title");
        box.pack_start (title_label, false, false, 0);

        var tagline = new Gtk.Label ("It fits on a CD");
        tagline.get_style_context ().add_class ("main-tagline");
        box.pack_start (tagline, false, false, 0);

        var desc = new Gtk.Label (
            "To keep the ISO size small, some drivers and optional components are not included on the install CD.\n\n" +
            "This wizard will help you restore them and set up your system."
        );
        desc.justify     = Gtk.Justification.CENTER;
        desc.wrap        = true;
        desc.max_width_chars = 60;
        desc.get_style_context ().add_class ("dim-label");
        box.pack_start (desc, false, false, 0);

        return box;
    }

    private Gtk.Widget build_options_page () {
        var outer = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        outer.margin = 40;

        var title = new Gtk.Label ("Restore Components");
        title.halign = Gtk.Align.START;
        title.get_style_context ().add_class ("section-title");
        outer.pack_start (title, false, false, 0);

        var sub = new Gtk.Label ("Select components your hardware requires. These packages will be downloaded and installed.");
        sub.halign        = Gtk.Align.START;
        sub.wrap          = true;
        sub.margin_top    = 4;
        sub.margin_bottom = 24;
        sub.get_style_context ().add_class ("dim-label");
        outer.pack_start (sub, false, false, 0);

        var list = new Gtk.ListBox ();
        list.selection_mode = Gtk.SelectionMode.NONE;
        list.get_style_context ().add_class ("options-list");
        
        list.row_activated.connect ((row) => {
            var box = (Gtk.Box) row.get_child ();
            var children = box.get_children ();
            foreach (var child in children) {
                if (child is Gtk.CheckButton) {
                    var cb = (Gtk.CheckButton) child;
                    cb.active = !cb.active;
                    break;
                }
            }
        });

        opt_bluetooth     = add_option (list,
            "Bluetooth Support",
            "Installs bluez, bluetooth managers, and common firmware blobs.",
            "bluetooth-symbolic");

        opt_mediatek_wifi = add_option (list,
            "MediaTek WiFi Firmware",
            "Provides drivers for MT7921/MT7922 and other modern MediaTek cards.",
            "network-wireless-symbolic");

        opt_full_firmware = add_option (list,
            "Full Linux Firmware",
            "Restores the complete linux-firmware package (recovers ~80MB of stripped files).",
            "drive-harddisk-symbolic");

        opt_printing = add_option (list,
            "Printing Support",
            "Installs CUPS and system-config-printer for local and network printing.",
            "printer-symbolic");

        opt_flatpak = add_option (list,
            "Flatpak + Flathub",
            "Enables Flatpak support and adds the universal Flathub repository.",
            "package-x-generic-symbolic");

        outer.pack_start (list, true, true, 0);
        return outer;
    }

    private Gtk.CheckButton add_option (Gtk.ListBox list, string name, string desc, string icon_name) {
        var row = new Gtk.ListBoxRow ();
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
        box.margin = 16;

        var icon = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.DND);
        icon.pixel_size = 32;
        box.pack_start (icon, false, false, 0);

        var text = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        var nl = new Gtk.Label (name);
        nl.halign = Gtk.Align.START;
        nl.get_style_context ().add_class ("option-name");
        text.pack_start (nl, false, false, 0);

        var dl = new Gtk.Label (desc);
        dl.halign = Gtk.Align.START;
        dl.get_style_context ().add_class ("dim-label");
        dl.wrap = true;
        dl.max_width_chars = 60;
        text.pack_start (dl, false, false, 0);

        box.pack_start (text, true, true, 0);

        var check = new Gtk.CheckButton ();
        check.valign = Gtk.Align.CENTER;
        check.can_focus = false;
        box.pack_end (check, false, false, 0);

        row.add (box);
        row.activatable = true;
        list.add (row);
        

        return check;
    }

    private Gtk.Widget build_utility_page () {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 32);
        box.halign = Gtk.Align.CENTER;
        box.valign = Gtk.Align.CENTER;
        box.margin = 48;

        var title = new Gtk.Label ("System Utilities");
        title.get_style_context ().add_class ("section-title");
        box.pack_start (title, false, false, 0);

        var grid = new Gtk.Grid ();
        grid.column_spacing = 20;
        grid.row_spacing = 20;
        grid.halign = Gtk.Align.CENTER;

        var btn_update = create_util_btn ("system-software-update-symbolic", "Run System Update", () => {
             spawn_cmd ("monody-updater");
        });
        grid.attach (btn_update, 0, 0, 1, 1);

        var btn_users = create_util_btn ("system-users-symbolic", "Manage Users", () => {
             spawn_cmd ("monody-users");
        });
        grid.attach (btn_users, 1, 0, 1, 1);

        box.pack_start (grid, false, false, 0);
        
        var hint = new Gtk.Label ("These utilities are also available in the application menu.");
        hint.get_style_context ().add_class ("dim-label");
        box.pack_start (hint, false, false, 0);

        return box;
    }

    private Gtk.Button create_util_btn (string icon, string label, owned Callback cb) {
        var b = new Gtk.Button ();
        var bx = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        bx.margin = 20;
        var img = new Gtk.Image.from_icon_name (icon, Gtk.IconSize.DIALOG);
        img.pixel_size = 64;
        bx.pack_start (img, false, false, 0);
        bx.pack_start (new Gtk.Label (label), false, false, 0);
        b.add (bx);
        b.get_style_context ().add_class ("util-btn");
        b.clicked.connect (() => { cb (); });
        return b;
    }

    private delegate void Callback ();

    private Gtk.Widget build_install_page () {
        term = new Vte.Terminal ();
        term.set_scroll_on_output (true);
        term.set_scrollback_lines (10000);

        var bg = Gdk.RGBA (); bg.parse ("#1a1b26");
        var fg = Gdk.RGBA (); fg.parse ("#a9b1d6");
        term.set_color_background (bg);
        term.set_color_foreground (fg);
        term.set_font (Pango.FontDescription.from_string ("Monospace 11"));

        term.child_exited.connect ((exit_status) => {
            install_running = false;
            spinner.stop ();
            spinner.hide ();

            if (exit_status == 0) {
                status_label.set_markup ("<b>✓ Done</b>");
                status_label.get_style_context ().add_class ("success-st");
            } else {
                status_label.set_markup ("<b>✗ Failed</b>");
                status_label.get_style_context ().add_class ("error-st");
            }
            status_label.show ();

            action_btn.label = "Next";
            action_btn.sensitive = true;
            action_btn.show ();
        });

        var sw = new Gtk.ScrolledWindow (null, null);
        sw.add (term);
        return sw;
    }

    private Gtk.Widget build_done_page () {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
        box.halign = Gtk.Align.CENTER;
        box.valign = Gtk.Align.CENTER;
        box.margin = 48;

        var icon = new Gtk.Image.from_icon_name ("emblem-default", Gtk.IconSize.DIALOG);
        icon.pixel_size = 128;
        icon.get_style_context ().add_class ("done-icon");
        box.pack_start (icon, false, false, 0);

        var title = new Gtk.Label ("You're all set!");
        title.get_style_context ().add_class ("welcome-title");
        box.pack_start (title, false, false, 0);

        var sub = new Gtk.Label ("Monody is configured and ready for your daily tasks.");
        sub.get_style_context ().add_class ("dim-label");
        box.pack_start (sub, false, false, 0);

        opt_dont_show = new Gtk.CheckButton.with_label ("Don't show this app again on startup");
        opt_dont_show.active = true;
        opt_dont_show.margin_top = 20;
        box.pack_start (opt_dont_show, false, false, 0);

        return box;
    }


    private void on_action_clicked () {
        string page = stack.visible_child_name;

        if (page == "welcome") {
            stack.visible_child_name = "options";
            action_btn.label = "Next";
            skip_btn.show ();

        } else if (page == "options") {
            string[] pkgs = build_pkgs ();
            if (pkgs.length == 0) {
                stack.visible_child_name = "utilities";
                action_btn.label = "Next";
                skip_btn.show ();
            } else {
                skip_btn.hide ();
                action_btn.hide ();
                start_install (pkgs);
            }

        } else if (page == "install") {
            stack.visible_child_name = "utilities";
            action_btn.label = "Next";
            skip_btn.show ();

        } else if (page == "utilities") {
            go_to_done ();

        } else if (page == "done") {
            this.destroy ();
        }
    }

    private void go_to_done () {
        stack.visible_child_name = "done";
        action_btn.label = "Finish";
        action_btn.show ();
        action_btn.sensitive = true;
        skip_btn.hide ();
        status_label.hide ();
    }

    private void on_skip_clicked () {
        if (stack.visible_child_name == "options") {
            stack.visible_child_name = "utilities";
            action_btn.label = "Next";
        } else if (stack.visible_child_name == "utilities") {
            go_to_done ();
        } else {
            go_to_done ();
        }
    }

    private string[] build_pkgs () {
        string[] res = {};
        if (opt_bluetooth.active) {
            res += "bluez"; res += "bluez-runit"; res += "blueman"; res += "linux-firmware-realtek";
        }
        if (opt_mediatek_wifi.active && !opt_full_firmware.active) {
            res += "linux-firmware-mediatek";
        }
        if (opt_full_firmware.active) {
            res += "linux-firmware";
        }
        if (opt_printing.active) {
            res += "cups"; res += "cups-runit"; res += "system-config-printer";
        }
        if (opt_flatpak.active) {
            res += "flatpak";
        }
        return res;
    }

    private void start_install (string[] pkgs) {
        install_running = true;
        spinner.show ();
        spinner.start ();
        status_label.set_text ("Downloading packages…");
        status_label.show ();

        stack.visible_child_name = "install";
        term.reset (true, true);

        string pkgs_str = string.joinv (" ", pkgs);
        string cmd = "pkexec bash -c 'pacman -Syu && pacman -S --noconfirm --needed " + pkgs_str + "'";
        if (opt_flatpak.active) {
            cmd += " && flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo";
        }

        string[] argv = { "/bin/bash", "-c", cmd };

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
                    install_running = false;
                    spinner.stop (); spinner.hide ();
                    status_label.set_markup ("<b>✗ Error</b>");
                    status_label.get_style_context ().add_class ("error-st");
                    action_btn.label = "Next"; action_btn.show ();
                }
            }
        );
    }

    private void spawn_cmd (string cmd) {
        try {
            Process.spawn_command_line_async (cmd);
        } catch (Error e) {}
    }

    private void on_close () {
        if (!install_running && opt_dont_show != null && opt_dont_show.active) {
            string path = Path.build_filename (Environment.get_home_dir (), ".config", "autostart", "monody-welcome.desktop");
            if (FileUtils.test (path, FileTest.EXISTS)) {
                FileUtils.remove (path);
            }
        }
        Gtk.main_quit ();
    }
}

int main (string[] args) {
    Gtk.init (ref args);
    var win = new WelcomeWindow ();
    win.show_all ();
    Gtk.main ();
    return 0;
}
