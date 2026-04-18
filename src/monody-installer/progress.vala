using Gtk;

public class ProgressPage : Box {
    private InstallConfig config;
    private ProgressBar progress_bar;
    private Label status_label;
    private Box tasks_box;
    private Box? current_task_row = null;
    private Image? current_task_icon = null;
    private Label? current_task_label = null;
    private Spinner? current_spinner = null;
    private TextView log_view;
    private TextBuffer log_buffer;
    private ScrolledWindow log_scroll;

    public signal void install_finished (bool success);

    public ProgressPage (InstallConfig config) {
        this.config = config;
        this.orientation = Orientation.HORIZONTAL;
        this.spacing = 0;
        this.margin = 0;

        var left_panel = new Box (Orientation.VERTICAL, 0);
        left_panel.set_size_request (280, -1);
        left_panel.get_style_context ().add_class ("info-badge");

        var brand_label = new Label ("");
        brand_label.use_markup = true;
        brand_label.label = "<span color='#7aa2f7' weight='ultrabold' size='x-large'>Monody</span>";
        brand_label.halign = Align.START;
        brand_label.margin = 20;
        brand_label.margin_bottom = 6;

        var installing_label = new Label ("");
        installing_label.use_markup = true;
        installing_label.label = "<span size='small' alpha='60%'>INSTALLING</span>";
        installing_label.halign = Align.START;
        installing_label.margin_start = 20;
        installing_label.margin_bottom = 16;

        var tasks_scroll = new ScrolledWindow (null, null);
        tasks_scroll.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);

        tasks_box = new Box (Orientation.VERTICAL, 2);
        tasks_box.margin_start = 16;
        tasks_box.margin_end = 16;
        tasks_scroll.add (tasks_box);

        left_panel.pack_start (brand_label, false, false, 0);
        left_panel.pack_start (installing_label, false, false, 0);
        left_panel.pack_start (tasks_scroll, true, true, 0);

        var right_panel = new Box (Orientation.VERTICAL, 8);
        right_panel.margin = 20;

        var logo = new Image ();
        try {
            var pixbuf = new Gdk.Pixbuf.from_file_at_scale ("/usr/share/pixmaps/monody.svg", 120, 120, true);
            logo.set_from_pixbuf (pixbuf);
        } catch (Error e) {
            logo.set_from_icon_name ("system-software-install", IconSize.DIALOG);
        }
        logo.halign = Align.CENTER;
        logo.margin_top = 10;
        logo.margin_bottom = 6;

        var header = new Label ("");
        header.use_markup = true;
        header.label = "<span color='#bb9af7' weight='bold' size='large'>Installation Progress</span>";
        header.halign = Align.CENTER;

        progress_bar = new ProgressBar ();
        progress_bar.show_text = true;
        progress_bar.set_size_request (400, -1);
        progress_bar.halign = Align.CENTER;
        progress_bar.margin_top = 8;

        status_label = new Label ("");
        status_label.get_style_context ().add_class ("page-desc");
        status_label.halign = Align.CENTER;
        status_label.ellipsize = Pango.EllipsizeMode.END;
        status_label.max_width_chars = 55;

        log_view = new TextView ();
        log_view.editable = false;
        log_view.monospace = true;
        log_view.wrap_mode = WrapMode.WORD_CHAR;
        log_buffer = log_view.buffer;

        log_scroll = new ScrolledWindow (null, null);
        log_scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        log_scroll.set_size_request (-1, 120);
        log_scroll.add (log_view);

        var expander = new Expander ("Show Logs");
        expander.add (log_scroll);
        expander.margin_top = 6;

        right_panel.pack_start (logo, false, false, 0);
        right_panel.pack_start (header, false, false, 0);
        right_panel.pack_start (progress_bar, false, false, 0);
        right_panel.pack_start (status_label, false, false, 4);
        right_panel.pack_start (expander, true, true, 0);

        this.pack_start (left_panel, false, false, 0);
        this.pack_start (new Separator (Orientation.VERTICAL), false, false, 0);
        this.pack_start (right_panel, true, true, 0);
    }

    private void complete_current_task () {
        if (current_task_row != null && current_spinner != null && current_task_icon != null) {
            current_spinner.stop ();
            current_spinner.hide ();
            current_task_icon.set_from_icon_name ("object-select-symbolic", IconSize.MENU);
            current_task_icon.show ();
            if (current_task_label != null) {
                string text = current_task_label.label;
                if (text.has_prefix ("<b>")) {
                    text = text.substring (3, text.length - 7);
                }
                current_task_label.use_markup = true;
                current_task_label.label = "<span color='#9ece6a'>" + text + "</span>";
            }
        }
    }

    private void add_task (string msg) {
        complete_current_task ();

        var row = new Box (Orientation.HORIZONTAL, 8);
        row.halign = Align.START;
        row.margin_top = 2;
        row.margin_bottom = 2;

        var icon = new Image ();
        icon.set_size_request (16, 16);
        icon.valign = Align.CENTER;
        icon.no_show_all = true;

        var spinner = new Spinner ();
        spinner.set_size_request (16, 16);
        spinner.valign = Align.CENTER;
        spinner.start ();

        var lbl = new Label ("");
        lbl.use_markup = true;
        lbl.label = "<b>" + GLib.Markup.escape_text (msg) + "</b>";
        lbl.halign = Align.START;
        lbl.ellipsize = Pango.EllipsizeMode.END;
        lbl.max_width_chars = 28;

        row.pack_start (icon, false, false, 0);
        row.pack_start (spinner, false, false, 0);
        row.pack_start (lbl, false, false, 0);

        tasks_box.pack_start (row, false, false, 0);
        row.show_all ();
        icon.hide ();

        current_task_row = row;
        current_task_icon = icon;
        current_task_label = lbl;
        current_spinner = spinner;
    }

    public void start_installation () {
        var engine = new InstallEngine (config);
        
        engine.progress_callback = (pct, msg) => {
            GLib.Idle.add (() => {
                progress_bar.fraction = pct / 100.0;
                progress_bar.text = pct.to_string () + "%";
                
                if (!msg.contains ("%")) {
                    if (current_task_label == null || !current_task_label.label.contains (GLib.Markup.escape_text (msg))) {
                        add_task (msg);
                    }
                }
                
                status_label.label = msg;
                return GLib.Source.REMOVE;
            });
        };

        engine.log_callback = (line) => {
            GLib.Idle.add (() => {
                TextIter iter;
                log_buffer.get_end_iter (out iter);
                log_buffer.insert (ref iter, line + "\n", -1);
                
                var adj = log_scroll.get_vadjustment ();
                adj.set_value (adj.get_upper () - adj.get_page_size ());
                return GLib.Source.REMOVE;
            });
        };

        engine.finished_callback = (success, msg) => {
            GLib.Idle.add (() => {
                if (success) {
                    complete_current_task ();
                    status_label.use_markup = true;
                    status_label.label = "<span color='#9ece6a' weight='bold'>Installation Complete! You may now reboot.</span>";
                    progress_bar.fraction = 1.0;
                    progress_bar.text = "100%";
                } else {
                    if (current_spinner != null) {
                        current_spinner.stop ();
                        current_spinner.hide ();
                    }
                    if (current_task_icon != null) {
                        current_task_icon.set_from_icon_name ("dialog-error-symbolic", IconSize.MENU);
                        current_task_icon.show ();
                    }
                    status_label.use_markup = true;
                    status_label.label = "<span color='#f7768e' weight='bold'>Installation Failed:</span> " + GLib.Markup.escape_text (msg);
                }
                install_finished (success);
                return GLib.Source.REMOVE;
            });
        };

        new Thread<void*> ("install-thread", () => {
            engine.run_install ();
            return null;
        });
    }
}