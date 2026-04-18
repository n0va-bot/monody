using Gtk;

public class SummaryPage : Box {
    private InstallConfig config;
    private Box cards_box;

    public SummaryPage (InstallConfig config) {
        this.config = config;
        this.orientation = Orientation.VERTICAL;
        this.spacing = 12;
        this.margin = 30;

        var header = new Label ("");
        header.use_markup = true;
        header.label = "<span color='#bb9af7' weight='bold' size='x-large'>Review Installation</span>";
        header.halign = Align.CENTER;

        var desc = new Label ("Please review your settings before proceeding.");
        desc.get_style_context ().add_class ("page-desc");
        desc.halign = Align.CENTER;
        desc.margin_bottom = 10;

        var scroll = new ScrolledWindow (null, null);
        scroll.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
        
        cards_box = new Box (Orientation.VERTICAL, 0);
        cards_box.halign = Align.CENTER;
        scroll.add (cards_box);

        this.pack_start (header, false, false, 0);
        this.pack_start (desc, false, false, 0);
        this.pack_start (scroll, true, true, 0);
    }

    public void refresh () {
        cards_box.get_children ().foreach ((child) => {
            cards_box.remove (child);
        });

        add_card ("drive-harddisk-symbolic", "Disk", config.disk, config.boot_mode.up () + " · " + (config.partition_mode == "auto" ? "Automatic" : "Manual"));
        add_card ("mark-location-symbolic", "Timezone", config.timezone, "");
        add_card ("input-keyboard-symbolic", "Keyboard", config.keymap, "");
        add_card ("avatar-default-symbolic", "User Account", config.display_name, config.username + " · Root: " + (config.root_pass != "" ? "Enabled" : "Disabled"));
        add_card ("computer-symbolic", "Hostname", config.hostname, "");
        add_card ("drive-removable-media-symbolic", "Swap", config.swap_size > 0 ? config.swap_size.to_string () + " MB" : "None", "");

        cards_box.show_all ();
    }

    private void add_card (string icon_name, string title, string primary, string secondary) {
        var card = new Box (Orientation.HORIZONTAL, 14);
        card.get_style_context ().add_class ("option-card");
        card.margin_start = 10;
        card.margin_end = 10;
        card.margin_top = 4;
        card.margin_bottom = 4;

        var icon = new Image.from_icon_name (icon_name, IconSize.DND);
        icon.valign = Align.CENTER;
        icon.margin_start = 10;

        var text_box = new Box (Orientation.VERTICAL, 2);
        text_box.valign = Align.CENTER;
        text_box.margin_top = 8;
        text_box.margin_bottom = 8;

        var title_label = new Label ("");
        title_label.use_markup = true;
        title_label.label = "<span size='small' weight='bold' color='#7aa2f7'>" + GLib.Markup.escape_text (title.up ()) + "</span>";
        title_label.xalign = 0;

        var value_label = new Label ("");
        value_label.use_markup = true;
        value_label.label = "<span weight='bold' size='large'>" + GLib.Markup.escape_text (primary) + "</span>";
        value_label.xalign = 0;
        value_label.ellipsize = Pango.EllipsizeMode.END;

        text_box.pack_start (title_label, false, false, 0);
        text_box.pack_start (value_label, false, false, 0);

        if (secondary != "") {
            var sec_label = new Label ("");
            sec_label.use_markup = true;
            sec_label.label = "<span size='small' alpha='60%'>" + GLib.Markup.escape_text (secondary) + "</span>";
            sec_label.xalign = 0;
            text_box.pack_start (sec_label, false, false, 0);
        }

        card.pack_start (icon, false, false, 6);
        card.pack_start (text_box, true, true, 4);

        cards_box.pack_start (card, false, false, 0);
    }
}