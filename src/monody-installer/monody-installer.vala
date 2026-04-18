using Gtk;

public class InstallerWindow : Gtk.Window {
    private InstallConfig config;
    private Gtk.Stack stack;
    private Gtk.Button back_btn;
    private Gtk.Button next_btn;
    private Gtk.Button cancel_btn;
    private Gtk.Button reboot_btn;
    private bool installing = false;

    private WelcomePage welcome_page;
    private DiskPage disk_page;
    private InstallTypePage install_type_page;
    private MountpointPage mountpoint_page;
    private TimezonePage timezone_page;
    private KeymapPage keymap_page;
    private UserPage user_page;
    private SummaryPage summary_page;
    private ProgressPage progress_page;

    private string[] page_names;
    private Gtk.Label[] dot_labels;
    private int current_page = 0;

    public InstallerWindow () {
        this.set_default_size (800, 600);
        this.title = "Monody Installer";
        this.set_position (Gtk.WindowPosition.CENTER);
        this.set_resizable (false);
        this.set_icon_name ("monody");

        this.delete_event.connect (() => {
            if (installing) return true;
            on_cancel ();
            return true;
        });

        config = new InstallConfig ();
        config.boot_mode = Utils.is_uefi () ? "uefi" : "bios";

        stack = new Gtk.Stack ();
        stack.set_transition_type (Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
        stack.set_transition_duration (200);

        welcome_page = new WelcomePage (config);
        disk_page = new DiskPage (config);
        install_type_page = new InstallTypePage (config);
        mountpoint_page = new MountpointPage (config);
        mountpoint_page.validation_changed.connect (() => { update_buttons (); });
        timezone_page = new TimezonePage (config);
        keymap_page = new KeymapPage (config);
        user_page = new UserPage (config);
        summary_page = new SummaryPage (config);
        progress_page = new ProgressPage (config);

        stack.add_named (welcome_page, "welcome");
        stack.add_named (disk_page, "disk");
        stack.add_named (install_type_page, "install_type");
        stack.add_named (mountpoint_page, "mountpoint");
        stack.add_named (timezone_page, "timezone");
        stack.add_named (keymap_page, "keymap");
        stack.add_named (user_page, "user");
        stack.add_named (summary_page, "summary");
        stack.add_named (progress_page, "progress");

        page_names = { "welcome", "disk", "install_type", "mountpoint", "timezone", "keymap", "user", "summary", "progress" };

        cancel_btn = new Gtk.Button.with_label ("Cancel");
        cancel_btn.get_style_context ().add_class ("destructive-action");
        cancel_btn.clicked.connect (on_cancel);

        back_btn = new Gtk.Button.with_label ("Back");
        back_btn.clicked.connect (on_back);

        reboot_btn = new Gtk.Button.with_label ("Reboot");
        reboot_btn.get_style_context ().add_class ("suggested-action");
        reboot_btn.no_show_all = true;
        reboot_btn.clicked.connect (() => {
            try {
                GLib.Process.spawn_command_line_async ("reboot");
            } catch (Error e) {
                warning ("Failed to reboot: %s", e.message);
            }
        });

        next_btn = new Gtk.Button.with_label ("Next");
        next_btn.get_style_context ().add_class ("suggested-action");
        next_btn.clicked.connect (on_next);

        var dots_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        dots_box.halign = Gtk.Align.CENTER;

        dot_labels = new Gtk.Label[page_names.length];
        for (int i = 0; i < page_names.length; i++) {
            dot_labels[i] = new Gtk.Label ("");
            dot_labels[i].use_markup = true;
            if (i == 0) {
                dot_labels[i].label = "<span color='#7aa2f7' font='14'>●</span>";
            } else {
                dot_labels[i].label = "<span color='#565f89' font='14'>●</span>";
            }
            dots_box.pack_start (dot_labels[i], false, false, 0);
        }

        var btn_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        btn_box.margin = 10;
        btn_box.pack_start (cancel_btn, false, false, 0);
        btn_box.pack_end (reboot_btn, false, false, 0);
        btn_box.pack_end (next_btn, false, false, 0);
        btn_box.pack_end (back_btn, false, false, 0);

        var bottom_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        bottom_box.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false, false, 0);
        bottom_box.pack_start (dots_box, false, false, 4);
        bottom_box.pack_start (btn_box, false, false, 0);

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_box.pack_start (stack, true, true, 0);
        main_box.pack_start (bottom_box, false, false, 0);

        this.add (main_box);

        disk_page.disk_selected.connect (() => { if (page_names[current_page] == "disk") update_buttons (); });
        user_page.validation_changed.connect ((v) => { if (page_names[current_page] == "user") next_btn.sensitive = v; });

        progress_page.install_finished.connect ((success) => {
            installing = false;
            next_btn.sensitive = true;
            if (success) {
                reboot_btn.show ();
            }
        });

        update_buttons ();
    }

    private void update_buttons () {
        back_btn.sensitive = current_page > 0;

        bool on_summary = page_names[current_page] == "summary";
        bool on_progress = page_names[current_page] == "progress";

        bool valid = true;
        if (page_names[current_page] == "disk") valid = (config.disk != "");
        if (page_names[current_page] == "user") valid = user_page.is_valid ();
        if (page_names[current_page] == "mountpoint") valid = mountpoint_page.is_valid ();
        next_btn.sensitive = valid;

        if (on_summary) {
            next_btn.label = "Install";
        } else if (on_progress) {
            next_btn.label = "Close";
            back_btn.sensitive = false;
            cancel_btn.sensitive = false;
            next_btn.sensitive = false;
        } else {
            next_btn.label = "Next";
        }

        for (int i = 0; i < dot_labels.length; i++) {
            if (i < current_page) {
                dot_labels[i].label = "<span color='#9ece6a' font='14'>●</span>";
            } else if (i == current_page) {
                dot_labels[i].label = "<span color='#7aa2f7' font='14'>●</span>";
            } else {
                dot_labels[i].label = "<span color='#565f89' font='14'>●</span>";
            }
        }
    }

    private bool check_encryption_password () {
        bool needs_pass = false;
        if (config.partition_mode == "auto" && config.encrypt_root) needs_pass = true;
        if (config.partition_mode == "manual") {
            foreach (var pm in config.mounts) {
                if (pm.encrypt) needs_pass = true;
            }
        }
        
        if (needs_pass && config.luks_password == "") {
            var dlg = new Gtk.Dialog.with_buttons ("LUKS Password", this, Gtk.DialogFlags.MODAL, "Cancel", Gtk.ResponseType.CANCEL, "OK", Gtk.ResponseType.OK);
            dlg.set_default_size (350, -1);

            var ok_btn = dlg.get_widget_for_response (Gtk.ResponseType.OK);
            ok_btn.sensitive = false;

            var entry = new Gtk.Entry ();
            entry.visibility = false;
            entry.placeholder_text = "Enter encryption password";
            var confirm = new Gtk.Entry ();
            confirm.visibility = false;
            confirm.placeholder_text = "Confirm password";

            var status_label = new Gtk.Label ("");
            status_label.use_markup = true;

            entry.changed.connect (() => {
                bool match = entry.text != "" && entry.text == confirm.text;
                ok_btn.sensitive = match;
                if (entry.text == "" || confirm.text == "") {
                    status_label.label = "";
                } else if (!match) {
                    status_label.label = "<span color='#f7768e'>Passwords do not match</span>";
                } else {
                    status_label.label = "<span color='#9ece6a'>Passwords match</span>";
                }
            });
            confirm.changed.connect (() => {
                bool match = entry.text != "" && entry.text == confirm.text;
                ok_btn.sensitive = match;
                if (entry.text == "" || confirm.text == "") {
                    status_label.label = "";
                } else if (!match) {
                    status_label.label = "<span color='#f7768e'>Passwords do not match</span>";
                } else {
                    status_label.label = "<span color='#9ece6a'>Passwords match</span>";
                }
            });

            var box = dlg.get_content_area ();
            box.margin = 12;
            box.spacing = 8;
            box.pack_start (new Gtk.Label ("Please enter a password for the encrypted partitions:"), false, false, 0);
            box.pack_start (entry, false, false, 0);
            box.pack_start (confirm, false, false, 0);
            box.pack_start (status_label, false, false, 0);
            box.show_all ();

            bool got_pass = false;
            if (dlg.run () == Gtk.ResponseType.OK) {
                config.luks_password = entry.text;
                got_pass = true;
            }
            dlg.destroy ();
            return got_pass;
        }
        return true;
    }

    private void on_next () {
        string name = page_names[current_page];

        if (name == "progress") {
            Gtk.main_quit ();
            return;
        }

        if (name == "install_type" && config.partition_mode == "auto") {
            if (!check_encryption_password ()) return;
        }

        if (name == "mountpoint") {
            if (!check_encryption_password ()) return;
        }

        if (name == "summary") {
            current_page++;
            installing = true;
            stack.set_visible_child_name (page_names[current_page]);
            update_buttons ();
            progress_page.start_installation ();
            return;
        }

        if (current_page < page_names.length - 1) {
            if (name == "install_type" && config.partition_mode == "auto") {
                current_page += 2;
            } else {
                current_page++;
            }
            
            string next_name = page_names[current_page];

            if (next_name == "disk") {
                disk_page.refresh ();
            } else if (next_name == "mountpoint") {
                mountpoint_page.launch_gparted ();
            } else if (next_name == "timezone") {
                timezone_page.refresh ();
            } else if (next_name == "summary") {
                summary_page.refresh ();
            }

            stack.set_visible_child_name (next_name);
            update_buttons ();
        }
    }

    private void on_back () {
        if (current_page > 0) {
            if (page_names[current_page] == "timezone" && config.partition_mode == "auto") {
                current_page -= 2;
            } else {
                current_page--;
            }
            stack.set_visible_child_name (page_names[current_page]);
            update_buttons ();
        }
    }

    private void on_cancel () {
        var dlg = new Gtk.MessageDialog (
            this,
            Gtk.DialogFlags.MODAL,
            Gtk.MessageType.QUESTION,
            Gtk.ButtonsType.YES_NO,
            "Are you sure you want to cancel the installation?"
        );
        dlg.title = "Cancel Installation";
        int resp = dlg.run ();
        dlg.destroy ();
        if (resp == Gtk.ResponseType.YES) {
            Gtk.main_quit ();
        }
    }
}

public static int main (string[] args) {
    if (Posix.geteuid () != 0) {
        warning ("Installer must be run as root!");
    }

    Gtk.init (ref args);

    var provider = new Gtk.CssProvider ();
    try {
        provider.load_from_data (
            ".main-title {\n" +
            "  font-family: 'Outfit', sans-serif;\n" +
            "  font-size: 64px;\n" +
            "  font-weight: 800;\n" +
            "  letter-spacing: -3px;\n" +
            "  color: #7aa2f7;\n" +
            "}\n" +
            ".main-tagline { font-size: 18px; font-weight: 500; }\n" +
            ".warning-text { color: #e0af68; font-size: 13px; }\n" +
            ".page-header {\n" +
            "  font-size: 22px;\n" +
            "  font-weight: bold;\n" +
            "  color: #bb9af7;\n" +
            "  margin-bottom: 4px;\n" +
            "}\n" +
            ".page-desc { font-size: 13px; margin-bottom: 12px; }\n" +
            ".info-badge {\n" +
            "  border-radius: 10px;\n" +
            "  padding: 12px 24px;\n" +
            "  border: 1px solid rgba(255, 255, 255, 0.1);\n" +
            "}\n" +
            ".badge-key {\n" +
            "  font-size: 10px;\n" +
            "  font-weight: bold;\n" +
            "  text-transform: uppercase;\n" +
            "  letter-spacing: 0.5px;\n" +
            "  opacity: 0.7;\n" +
            "}\n" +
            ".badge-value { font-size: 16px; font-weight: bold; }\n" +
            ".option-card {\n" +
            "  border-radius: 8px;\n" +
            "  border: 1px solid rgba(255, 255, 255, 0.1);\n" +
            "  padding: 4px;\n" +
            "}\n" +
            ".option-title { font-weight: bold; font-size: 14px; }\n" +
            ".option-desc { font-size: 12px; }\n" +
            ".form-label { font-weight: bold; font-size: 13px; }\n"
        );
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER
        );
    } catch (Error e) {}

    var win = new InstallerWindow ();
    win.show_all ();

    Gtk.main ();
    return 0;
}