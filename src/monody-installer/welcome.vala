using Gtk;

public class WelcomePage : Box {
    private InstallConfig config;

    public WelcomePage (InstallConfig config) {
        this.config = config;
        this.orientation = Orientation.VERTICAL;
        this.spacing = 16;
        this.margin = 24;

        var right_box = new Box (Orientation.VERTICAL, 16);
        right_box.valign = Align.CENTER;
        right_box.halign = Align.CENTER;

        var title = new Label ("<span font_size='xx-large' font_weight='bold'>Install Monody Linux</span>");
        title.use_markup = true;

        var desc = new Label (
                              "You may wish to read the release notes or update this installer.\n\n"
                              + "Please back up your data before proceeding."
        );
        desc.justify = Justification.CENTER;

        right_box.pack_start (title, false, false, 0);
        right_box.pack_start (desc, false, false, 0);

        this.pack_start (right_box, true, true, 0);
    }
}
