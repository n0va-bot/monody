using Gtk;

public class WelcomePage : Box {
    private InstallConfig config;

    public WelcomePage (InstallConfig config) {
        this.config = config;
        this.orientation = Orientation.VERTICAL;
        this.spacing = 0;
        this.valign = Align.CENTER;
        this.halign = Align.CENTER;
        this.margin = 48;

        var icon = new Gtk.Image ();
        try {
            var pixbuf = new Gdk.Pixbuf.from_file_at_scale (
                "/usr/share/pixmaps/monody.svg", 128, 128, true
            );
            icon.set_from_pixbuf (pixbuf);
        } catch (Error e) {
            icon.set_from_icon_name ("monody", Gtk.IconSize.DIALOG);
            icon.pixel_size = 128;
        }

        var title = new Label ("monody");
        title.get_style_context ().add_class ("main-title");

        var tagline = new Label ("Installation Wizard");
        tagline.get_style_context ().add_class ("main-tagline");

        var desc = new Label (
            "This wizard will guide you through installing Monody Linux\n" +
            "to your hard drive. Please back up any important data before proceeding."
        );
        desc.justify = Justification.CENTER;
        desc.wrap = true;
        desc.max_width_chars = 60;
        desc.get_style_context ().add_class ("dim-label");

        var boot_mode_str = config.boot_mode.up ();

        var info_box = new Box (Orientation.HORIZONTAL, 16);
        info_box.halign = Align.CENTER;
        info_box.margin_top = 24;

        var boot_badge = make_badge ("drive-harddisk-symbolic", "Boot Mode", boot_mode_str);
        var bl_badge = make_badge ("system-run-symbolic", "Bootloader", "Limine");

        info_box.pack_start (boot_badge, false, false, 0);
        info_box.pack_start (bl_badge, false, false, 0);

        var warning_label = new Label ("⚠  The selected disk will be completely erased.");
        warning_label.get_style_context ().add_class ("warning-text");
        warning_label.margin_top = 24;

        this.pack_start (icon, false, false, 0);
        this.pack_start (title, false, false, 6);
        this.pack_start (tagline, false, false, 4);
        this.pack_start (desc, false, false, 16);
        this.pack_start (info_box, false, false, 0);
        this.pack_start (warning_label, false, false, 0);
    }

    private Gtk.Widget make_badge (string icon_name, string key, string val) {
        var box = new Box (Orientation.HORIZONTAL, 12);
        box.get_style_context ().add_class ("info-badge");
        box.valign = Align.CENTER;

        var icon = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.LARGE_TOOLBAR);
        icon.pixel_size = 24;

        var text_box = new Box (Orientation.VERTICAL, 0);
        text_box.valign = Align.CENTER;

        var k = new Label (key);
        k.get_style_context ().add_class ("badge-key");
        k.xalign = 0;

        var v = new Label (val);
        v.get_style_context ().add_class ("badge-value");
        v.xalign = 0;

        text_box.pack_start (k, false, false, 0);
        text_box.pack_start (v, false, false, 0);

        box.pack_start (icon, false, false, 0);
        box.pack_start (text_box, true, true, 0);
        
        box.set_size_request (-1, 54);

        return box;
    }
}