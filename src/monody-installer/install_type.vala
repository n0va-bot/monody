using Gtk;

public class InstallTypePage : Box {
    private InstallConfig config;
    public RadioButton auto_btn;
    public RadioButton manual_btn;
    
    private Box auto_advanced_box;
    private ComboBoxText fs_combo;
    private CheckButton encrypt_check;
    public Entry pass_entry;
    public Entry pass_confirm_entry;

    public InstallTypePage (InstallConfig config) {
        this.config = config;
        this.orientation = Orientation.VERTICAL;
        this.spacing = 12;
        this.margin = 30;

        var header = new Label ("Installation type");
        header.get_style_context ().add_class ("page-header");
        header.xalign = 0;

        var desc = new Label ("How would you like to install Monody?");
        desc.get_style_context ().add_class ("page-desc");
        desc.xalign = 0;

        auto_btn = new RadioButton.with_label (null, "Erase disk and install Monody");
        auto_btn.get_style_context ().add_class ("option-title");
        var auto_box = new Box (Orientation.VERTICAL, 4);
        auto_box.margin_start = 32;
        var auto_desc = new Label ("Warning: This will delete all data on the selected disk.");
        auto_desc.get_style_context ().add_class ("option-desc");
        auto_desc.wrap = true;
        auto_desc.xalign = 0;
        
        var auto_expander = new Expander ("Advanced Options");
        auto_advanced_box = new Box (Orientation.VERTICAL, 6);
        auto_advanced_box.margin_top = 6;
        auto_advanced_box.margin_start = 10;
        
        var fs_box = new Box (Orientation.HORIZONTAL, 10);
        fs_box.pack_start (new Label ("Filesystem:"), false, false, 0);
        fs_combo = new ComboBoxText ();
        fs_combo.append ("btrfs", "Btrfs (Recommended)");
        fs_combo.append ("ext4", "Ext4");
        fs_combo.active_id = "btrfs";
        fs_combo.changed.connect (() => { config.root_fs = fs_combo.active_id; });
        fs_box.pack_start (fs_combo, false, false, 0);
        
        encrypt_check = new CheckButton.with_label ("Encrypt system (LUKS)");
        
        var pass_grid = new Grid ();
        pass_grid.row_spacing = 6;
        pass_grid.column_spacing = 10;
        pass_grid.margin_start = 24;
        pass_grid.margin_top = 4;
        
        pass_entry = new Entry ();
        pass_entry.visibility = false;
        pass_entry.placeholder_text = "Encryption password";
        pass_confirm_entry = new Entry ();
        pass_confirm_entry.visibility = false;
        pass_confirm_entry.placeholder_text = "Confirm password";
        
        pass_grid.attach (new Label ("Password:"), 0, 0, 1, 1);
        pass_grid.attach (pass_entry, 1, 0, 1, 1);
        pass_grid.attach (new Label ("Confirm:"), 0, 1, 1, 1);
        pass_grid.attach (pass_confirm_entry, 1, 1, 1, 1);
        pass_grid.no_show_all = true;
        
        encrypt_check.toggled.connect (() => {
            config.encrypt_root = encrypt_check.active;
            pass_grid.visible = encrypt_check.active;
        });
        
        pass_entry.changed.connect (validate_passwords);
        pass_confirm_entry.changed.connect (validate_passwords);
        
        auto_advanced_box.pack_start (fs_box, false, false, 0);
        auto_advanced_box.pack_start (encrypt_check, false, false, 0);
        auto_advanced_box.pack_start (pass_grid, false, false, 0);
        auto_expander.add (auto_advanced_box);
        
        auto_box.pack_start (auto_desc, false, false, 0);
        auto_box.pack_start (auto_expander, false, false, 6);

        var auto_card = new Box (Orientation.VERTICAL, 6);
        auto_card.pack_start (auto_btn, false, false, 0);
        auto_card.pack_start (auto_box, false, false, 0);

        manual_btn = new RadioButton.with_label_from_widget (auto_btn, "Partition manually");
        manual_btn.get_style_context ().add_class ("option-title");
        var manual_desc_lbl = new Label ("Partition the disk yourself");
        manual_desc_lbl.get_style_context ().add_class ("option-desc");
        manual_desc_lbl.wrap = true;
        manual_desc_lbl.xalign = 0;
        manual_desc_lbl.margin_start = 32;

        var manual_card = new Box (Orientation.VERTICAL, 6);
        manual_card.pack_start (manual_btn, false, false, 0);
        manual_card.pack_start (manual_desc_lbl, false, false, 0);

        var options_box = new Box (Orientation.VERTICAL, 16);
        options_box.margin_top = 10;
        options_box.pack_start (auto_card, false, false, 0);
        options_box.pack_start (manual_card, false, false, 0);

        auto_btn.toggled.connect (() => {
            if (auto_btn.active) {
                config.partition_mode = "auto";
            }
        });
        manual_btn.toggled.connect (() => {
            if (manual_btn.active) {
                config.partition_mode = "manual";
            }
        });
        auto_btn.active = true;

        this.pack_start (header, false, false, 0);
        this.pack_start (desc, false, false, 0);
        this.pack_start (options_box, false, false, 0);
    }

    private void validate_passwords () {
        if (pass_entry.text != pass_confirm_entry.text) {
            pass_entry.get_style_context ().add_class ("error");
            pass_confirm_entry.get_style_context ().add_class ("error");
            config.luks_password = "";
        } else {
            pass_entry.get_style_context ().remove_class ("error");
            pass_confirm_entry.get_style_context ().remove_class ("error");
            config.luks_password = pass_entry.text;
        }
    }
}