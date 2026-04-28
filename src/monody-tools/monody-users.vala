using Gtk;
using GLib;

public class UserInfo : Object {
    public string name;
    public int uid;
    public string display;
    public string home;
    public string[] groups;
    public bool locked;
}

public class UserRow : Gtk.ListBoxRow {
    public UserInfo info;

    public static Gdk.Pixbuf crop_circle (Gdk.Pixbuf src, int size) {
        int w = src.width;
        int h = src.height;
        int s = int.min (w, h);
        var square = new Gdk.Pixbuf.subpixbuf (src, (w - s) / 2, (h - s) / 2, s, s);
        var scaled = square.scale_simple (size, size, Gdk.InterpType.BILINEAR);
        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, size, size);
        var cr = new Cairo.Context (surface);
        cr.arc (size / 2.0, size / 2.0, size / 2.0, 0, 2 * Math.PI);
        cr.clip ();
        Gdk.cairo_set_source_pixbuf (cr, scaled, 0, 0);
        cr.paint ();
        return Gdk.pixbuf_get_from_surface (surface, 0, 0, size, size);
    }

    public UserRow (UserInfo info) {
        this.info = info;

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        box.margin = 8;
        
        string icon_path = "/var/lib/AccountsService/icons/" + info.name;
        Gtk.Image pfp;
        if (FileUtils.test (info.home + "/.face", FileTest.EXISTS)) {
            pfp = new Gtk.Image.from_file (info.home + "/.face");
        } else if (FileUtils.test (icon_path, FileTest.EXISTS)) {
            pfp = new Gtk.Image.from_file (icon_path);
        } else {
            pfp = new Gtk.Image.from_icon_name ("avatar-default", Gtk.IconSize.DND);
        }
        
        try {
            var pb = pfp.get_pixbuf ();
            if (pb != null) {
                pfp.set_from_pixbuf (crop_circle (pb, 48));
            } else {
                pfp.pixel_size = 48;
            }
        } catch (Error e) {
            pfp = new Gtk.Image.from_icon_name ("avatar-default", Gtk.IconSize.DND);
            pfp.pixel_size = 48;
        }

        box.pack_start (pfp, false, false, 0);

        var text_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        text_box.valign = Gtk.Align.CENTER;

        var label_main = new Gtk.Label (null);
        label_main.set_markup ("<b>%s</b>".printf (Markup.escape_text (info.display.make_valid ())));
        label_main.halign = Gtk.Align.START;
        text_box.pack_start (label_main, false, false, 0);

        var label_sub = new Gtk.Label (info.name);
        label_sub.halign = Gtk.Align.START;
        label_sub.get_style_context ().add_class ("dim-label");
        text_box.pack_start (label_sub, false, false, 0);

        box.pack_start (text_box, true, true, 0);
        
        if (info.locked) {
            var lock_icon = new Gtk.Image.from_icon_name ("changes-prevent-symbolic", Gtk.IconSize.MENU);
            lock_icon.get_style_context ().add_class ("dim-label");
            box.pack_end (lock_icon, false, false, 0);
            this.opacity = 0.6;
        }

        this.add (box);
    }
}

public class UserManager : Gtk.Box {

    private Gtk.ListBox list;
    private UserInfo? current = null;

    private Gtk.Image p_avatar;
    private Gtk.EventBox p_avatar_event;
    private Gtk.Label l_display;
    private Gtk.Stack name_stack;
    private Gtk.Entry e_inline_name;
    private Gtk.Label l_name;
    private Gtk.Label l_group;
    
    private Gtk.Switch s_admin;

    private Gtk.Stack stack;
    
    private string current_username;

    private const string CSS = """
        .sidebar { background-color: shade(@theme_bg_color, 0.96); }
        .sidebar row { padding: 4px 8px; border-radius: 6px; margin: 2px 6px; }
        .sidebar row:selected { background-color: @theme_selected_bg_color; }
        .btn-wide { min-height: 36px; min-width: 180px; }
        .name-label { font-size: 20px; font-weight: bold; }
        .name-label-click { font-size: 20px; font-weight: bold; }
        .name-label-click:hover { opacity: 0.7; }
        .avatar-click:hover { opacity: 0.8; }
        .avatar-badge { background: alpha(@theme_bg_color, 0.75); border-radius: 50%; padding: 4px; }
        .edit-hint { opacity: 0.4; }
        .edit-hint:hover { opacity: 0.8; }
        .success-icon { color: #50fa7b; }
    """;

    construct {
        this.orientation = Gtk.Orientation.HORIZONTAL;

        current_username = Environment.get_user_name ();

        var prov = new Gtk.CssProvider ();
        try {
            prov.load_from_data (CSS);
            Gtk.StyleContext.add_provider_for_screen (
                Gdk.Screen.get_default (), prov,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {}

        var paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);

        var sidebar_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

        var sw = new Gtk.ScrolledWindow (null, null);
        sw.hscrollbar_policy = Gtk.PolicyType.NEVER;
        sw.min_content_width = 240;
        sw.get_style_context ().add_class ("sidebar");

        list = new Gtk.ListBox ();
        list.selection_mode = Gtk.SelectionMode.SINGLE;
        list.row_selected.connect (on_row_selected);
        sw.add (list);
        sidebar_box.pack_start (sw, true, true, 0);

        var add_btn = new Gtk.Button.with_label ("Add User");
        add_btn.image = new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.BUTTON);
        add_btn.always_show_image = true;
        add_btn.get_style_context ().add_class ("suggested-action");
        add_btn.clicked.connect (show_add_dialog);
        add_btn.margin = 8;
        sidebar_box.pack_start (add_btn, false, false, 0);

        paned.pack1 (sidebar_box, false, false);

        stack = new Gtk.Stack ();
        stack.transition_type = Gtk.StackTransitionType.CROSSFADE;

        var empty_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        empty_box.valign = Gtk.Align.CENTER;
        empty_box.halign = Gtk.Align.CENTER;

        var e_img = new Gtk.Image.from_icon_name ("system-users", Gtk.IconSize.DIALOG);
        e_img.pixel_size = 64;
        e_img.opacity = 0.3;
        empty_box.pack_start (e_img, false, false, 0);

        var e_lbl = new Gtk.Label ("Select a user to view details");
        e_lbl.get_style_context ().add_class ("dim-label");
        empty_box.pack_start (e_lbl, false, false, 0);
        stack.add_named (empty_box, "empty");

        var dsw = new Gtk.ScrolledWindow (null, null);
        var detail_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
        detail_box.margin = 32;
        detail_box.halign = Gtk.Align.CENTER;
        detail_box.valign = Gtk.Align.START;

        p_avatar = new Gtk.Image.from_icon_name ("avatar-default", Gtk.IconSize.DIALOG);
        var avatar_overlay = new Gtk.Overlay ();
        avatar_overlay.halign = Gtk.Align.CENTER;
        p_avatar_event = new Gtk.EventBox ();
        p_avatar_event.add (p_avatar);
        p_avatar_event.get_style_context ().add_class ("avatar-click");
        p_avatar_event.realize.connect (() => {
            p_avatar_event.get_window ().set_cursor (new Gdk.Cursor.for_display (p_avatar_event.get_display (), Gdk.CursorType.HAND2));
        });
        p_avatar_event.button_press_event.connect ((ev) => {
            if (ev.button == 1) { pick_avatar (); return true; }
            return false;
        });
        avatar_overlay.add (p_avatar_event);
        var badge = new Gtk.Image.from_icon_name ("document-edit-symbolic", Gtk.IconSize.MENU);
        badge.get_style_context ().add_class ("avatar-badge");
        badge.halign = Gtk.Align.END;
        badge.valign = Gtk.Align.END;
        badge.margin_end = 2;
        badge.margin_bottom = 2;
        badge.no_show_all = true;
        badge.hide ();
        avatar_overlay.add_overlay (badge);
        p_avatar_event.enter_notify_event.connect (() => { badge.show (); return false; });
        p_avatar_event.leave_notify_event.connect (() => { badge.hide (); return false; });
        detail_box.pack_start (avatar_overlay, false, false, 0);

        var header = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
        header.halign = Gtk.Align.CENTER;

        name_stack = new Gtk.Stack ();
        name_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;

        var display_event = new Gtk.EventBox ();
        var display_inner = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        display_inner.halign = Gtk.Align.CENTER;
        l_display = new Gtk.Label ("");
        l_display.get_style_context ().add_class ("name-label-click");
        var name_edit_icon = new Gtk.Image.from_icon_name ("document-edit-symbolic", Gtk.IconSize.MENU);
        name_edit_icon.get_style_context ().add_class ("edit-hint");
        name_edit_icon.no_show_all = true;
        name_edit_icon.hide ();
        display_inner.pack_start (l_display, false, false, 0);
        display_inner.pack_start (name_edit_icon, false, false, 0);
        display_event.add (display_inner);
        display_event.realize.connect (() => {
            display_event.get_window ().set_cursor (new Gdk.Cursor.for_display (display_event.get_display (), Gdk.CursorType.HAND2));
        });
        display_event.enter_notify_event.connect (() => { name_edit_icon.show (); return false; });
        display_event.leave_notify_event.connect (() => { name_edit_icon.hide (); return false; });
        display_event.button_press_event.connect ((ev) => {
            if (ev.button == 1 && current != null) {
                e_inline_name.text = current.display.make_valid ();
                name_stack.visible_child_name = "edit";
                e_inline_name.grab_focus ();
                return true;
            }
            return false;
        });
        name_stack.add_named (display_event, "label");

        var edit_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        edit_box.halign = Gtk.Align.CENTER;
        e_inline_name = new Gtk.Entry ();
        e_inline_name.width_chars = 20;
        var save_btn = new Gtk.Button.from_icon_name ("object-select-symbolic", Gtk.IconSize.BUTTON);
        save_btn.get_style_context ().add_class ("suggested-action");
        var cancel_btn = new Gtk.Button.from_icon_name ("process-stop-symbolic", Gtk.IconSize.BUTTON);
        edit_box.pack_start (e_inline_name, true, true, 0);
        edit_box.pack_start (save_btn, false, false, 0);
        edit_box.pack_start (cancel_btn, false, false, 0);
        name_stack.add_named (edit_box, "edit");

        save_btn.clicked.connect (() => { apply_inline_name (); });
        cancel_btn.clicked.connect (() => { name_stack.visible_child_name = "label"; });
        e_inline_name.activate.connect (() => { apply_inline_name (); });

        header.pack_start (name_stack, false, false, 0);

        l_name = new Gtk.Label ("");
        l_name.get_style_context ().add_class ("dim-label");
        header.pack_start (l_name, false, false, 0);
        
        l_group = new Gtk.Label ("");
        l_group.get_style_context ().add_class ("dim-label");
        header.pack_start (l_group, false, false, 0);

        detail_box.pack_start (header, false, false, 0);
        
        var grid = new Gtk.Grid ();
        grid.column_spacing = 24;
        grid.row_spacing = 16;
        grid.halign = Gtk.Align.CENTER;
        
        var l_adm = new Gtk.Label ("Administrator");
        l_adm.halign = Gtk.Align.END;
        grid.attach (l_adm, 0, 0, 1, 1);
        
        s_admin = new Gtk.Switch ();
        s_admin.halign = Gtk.Align.START;
        s_admin.valign = Gtk.Align.CENTER;
        s_admin.notify["active"].connect (on_admin_toggled);
        grid.attach (s_admin, 1, 0, 1, 1);
        
        detail_box.pack_start (grid, false, false, 0);

        var act_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
        act_box.halign = Gtk.Align.CENTER;
        act_box.margin_top = 16;
        
        act_box.pack_start (create_btn ("dialog-password-symbolic", "Change Password", show_password_dialog), false, false, 0);

        var del_btn = create_btn ("edit-delete-symbolic", "Delete User", show_delete_dialog);
        del_btn.get_style_context ().add_class ("destructive-action");
        act_box.pack_start (del_btn, false, false, 0);

        detail_box.pack_start (act_box, false, false, 0);
        dsw.add (detail_box);
        stack.add_named (dsw, "detail");

        stack.visible_child_name = "empty";
        paned.pack2 (stack, true, false);
        paned.position = 240;
        this.pack_start (paned, true, true, 0);

        reload_users ();
    }

    private Gtk.Button create_btn (string icon, string label, owned Callback cb) {
        var b = new Gtk.Button ();
        var bx = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        bx.pack_start (new Gtk.Image.from_icon_name (icon, Gtk.IconSize.BUTTON), false, false, 0);
        bx.pack_start (new Gtk.Label (label), false, false, 0);
        b.add (bx);
        b.get_style_context ().add_class ("btn-wide");
        b.clicked.connect (() => { cb (); });
        return b;
    }

    private delegate void Callback ();

    private void reload_users () {
        list.foreach ((w) => { w.destroy (); });
        current = null;
        stack.visible_child_name = "empty";

        try {
            string raw;
            FileUtils.get_contents ("/etc/passwd", out raw);

            foreach (unowned string line in raw.split ("\n")) {
                if (line.strip () == "") continue;
                string[] f = line.split (":");
                if (f.length < 7) continue;

                int uid = int.parse (f[2]);
                if (uid < 1000 || f[0] == "nobody") continue;

                var u = new UserInfo ();
                u.name = f[0];
                u.uid = uid;
                
                if (f[4] != null && f[4] != "") {
                    string[] parts = f[4].split (",");
                    u.display = parts[0];
                } else {
                    u.display = f[0];
                }
                
                u.home = f[5];
                u.groups = get_user_groups (f[0]);
                u.locked = (u.name != current_username);

                list.add (new UserRow (u));
            }
        } catch (Error e) {
            warn ("Cannot read passwords: " + e.message);
        }
        list.show_all ();
        reselect (current_username);
    }

    private string[] get_user_groups (string u) {
        string? raw = cmd_sync ("id -nG " + Shell.quote (u));
        if (raw == null) return new string[0];
        string[] res = {};
        foreach (string g in raw.split (" ")) {
            if (g.strip () != "") res += g.strip ();
        }
        return res;
    }

    private void on_row_selected (Gtk.ListBoxRow? r) {
        if (r == null) {
            stack.visible_child_name = "empty";
            return;
        }

        var row = (UserRow) r;
        var u = row.info;

        current = u;
        l_display.label = u.display.make_valid ();
        name_stack.visible_child_name = "label";
        l_name.label = "@" + u.name;
        
        bool is_adm = false;
        foreach (string g in u.groups) {
            if (g == "wheel") is_adm = true;
        }
        
        l_group.label = is_adm ? "Administrator" : "Standard User";
        s_admin.active = is_adm;

        string p = "/var/lib/AccountsService/icons/" + u.name;
        if (FileUtils.test (u.home + "/.face", FileTest.EXISTS)) {
            load_pfp (u.home + "/.face");
        } else if (FileUtils.test (p, FileTest.EXISTS)) {
            load_pfp (p);
        } else {
            p_avatar.set_from_icon_name ("avatar-default", Gtk.IconSize.DIALOG);
            p_avatar.pixel_size = 96;
        }

        stack.visible_child_name = "detail";
    }
    
    private void load_pfp (string path) {
        try {
            var px = new Gdk.Pixbuf.from_file (path);
            p_avatar.set_from_pixbuf (UserRow.crop_circle (px, 96));
        } catch (Error e) {
            p_avatar.set_from_icon_name ("avatar-default", Gtk.IconSize.DIALOG);
            p_avatar.pixel_size = 96;
        }
    }
    
    private void on_admin_toggled () {
        if (current == null) return;
        bool t = s_admin.active;
        bool has = false;
        foreach (string g in current.groups) { if (g == "wheel") has = true; }
        
        if (t && !has) {
            if (cmd_auth ("usermod -aG wheel " + Shell.quote (current.name))) {
                string saved = current.name;
                reload_users ();
                reselect (saved);
            } else {
                s_admin.active = false;
            }
        } else if (!t && has) {
            if (cmd_auth ("gpasswd -d %s wheel".printf (Shell.quote (current.name)))) {
                string saved = current.name;
                reload_users ();
                reselect (saved);
            } else {
                s_admin.active = true;
            }
        }
    }

    private void apply_inline_name () {
        if (current == null) return;
        string new_name = e_inline_name.text.strip ();
        if (new_name == "" || new_name == current.display) {
            name_stack.visible_child_name = "label";
            return;
        }
        if (cmd_auth ("usermod -c %s %s".printf (Shell.quote (new_name.replace (",", "")), Shell.quote (current.name)))) {
            string saved = current.name;
            reload_users ();
            reselect (saved);
        }
        name_stack.visible_child_name = "label";
    }

    private void pick_avatar () {
        if (current == null) return;

        var fc = new Gtk.FileChooserDialog ("Select Profile Picture", this.get_toplevel () as Gtk.Window,
            Gtk.FileChooserAction.OPEN,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Open", Gtk.ResponseType.ACCEPT);
        var ff = new Gtk.FileFilter ();
        ff.add_pixbuf_formats ();
        ff.set_name ("Images");
        fc.add_filter (ff);

        if (fc.run () == Gtk.ResponseType.ACCEPT) {
            string file = fc.get_filename ();
            if (file != null) {
                string target = "%s/.face".printf (current.home);
                string uid_o = cmd_sync ("id -u " + Shell.quote (current.name));
                string dbus_cmd = "busctl call org.freedesktop.Accounts /org/freedesktop/Accounts/User%s org.freedesktop.Accounts.User SetIconFile s %s".printf (uid_o, Shell.quote (target));

                if (current.name == current_username) {
                    cmd_sync ("bash -c 'cp %s %s && chmod 0644 %s && %s'".printf (
                        Shell.quote (file), Shell.quote (target), Shell.quote (target), dbus_cmd));
                } else {
                    cmd_auth ("bash -c 'cp %s %s && chown %s %s && chmod 0644 %s && %s'".printf (
                        Shell.quote (file), Shell.quote (target), Shell.quote (current.name), Shell.quote (target), Shell.quote (target), dbus_cmd));
                }
                string saved = current.name;
                reload_users ();
                reselect (saved);
            }
        }
        fc.destroy ();
    }

    private void show_add_dialog () {
        var d = new Gtk.Dialog.with_buttons (
            "Add User", this.get_toplevel () as Gtk.Window,
            Gtk.DialogFlags.MODAL,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Create", Gtk.ResponseType.OK);
        d.set_default_size (400, -1);
        
        var create_btn = d.get_widget_for_response (Gtk.ResponseType.OK);
        create_btn.get_style_context ().add_class ("suggested-action");
        create_btn.sensitive = false;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12; grid.row_spacing = 14; grid.margin = 20;

        var l1 = new Gtk.Label ("Display Name:"); l1.halign = Gtk.Align.END; grid.attach (l1, 0, 0, 1, 1);
        var e_disp = new Gtk.Entry (); grid.attach (e_disp, 1, 0, 1, 1); e_disp.hexpand = true;

        var l2 = new Gtk.Label ("Username:"); l2.halign = Gtk.Align.END; grid.attach (l2, 0, 1, 1, 1);
        var e_user = new Gtk.Entry (); grid.attach (e_user, 1, 1, 1, 1);
        
        grid.attach (new Gtk.Label ("Profile Picture:"), 0, 2, 1, 1);
        var fc = new Gtk.FileChooserButton ("Select Image", Gtk.FileChooserAction.OPEN);
        var ff = new Gtk.FileFilter ();
        ff.add_pixbuf_formats ();
        ff.set_name ("Images");
        fc.add_filter (ff);
        grid.attach (fc, 1, 2, 1, 1);
        
        var l3 = new Gtk.Label ("Password:"); l3.halign = Gtk.Align.END; grid.attach (l3, 0, 3, 1, 1);
        var e_pw1 = new Gtk.Entry (); e_pw1.visibility = false; grid.attach (e_pw1, 1, 3, 1, 1);
        
        var l4 = new Gtk.Label ("Confirm:"); l4.halign = Gtk.Align.END; grid.attach (l4, 0, 4, 1, 1);
        
        var pw_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var e_pw2 = new Gtk.Entry (); e_pw2.visibility = false; e_pw2.hexpand = true;
        var p_icon = new Gtk.Image.from_icon_name ("dialog-ok-symbolic", Gtk.IconSize.MENU);
        p_icon.get_style_context ().add_class ("success-icon");
        p_icon.opacity = 0;
        pw_box.pack_start (e_pw2, true, true, 0);
        pw_box.pack_start (p_icon, false, false, 0);
        grid.attach (pw_box, 1, 4, 1, 1);

        var c_adm = new Gtk.CheckButton.with_label ("Administrator");
        grid.attach (c_adm, 1, 5, 1, 1);

        e_disp.changed.connect (() => {
            if (!e_user.has_focus) {
                try {
                    var r = new Regex ("[^a-z0-9_]");
                    e_user.text = r.replace (e_disp.text.down (), e_disp.text.length, 0, "");
                } catch (Error e) {}
            }
        });
        
        e_user.changed.connect (() => {
            bool ok = e_user.text != "" && e_pw1.text != "" && (e_pw1.text == e_pw2.text);
            create_btn.sensitive = ok;
            p_icon.opacity = (e_pw1.text != "" && e_pw1.text == e_pw2.text) ? 1.0 : 0.0;
        });
        e_pw1.changed.connect (() => {
            bool ok = e_user.text != "" && e_pw1.text != "" && (e_pw1.text == e_pw2.text);
            create_btn.sensitive = ok;
            p_icon.opacity = (e_pw1.text != "" && e_pw1.text == e_pw2.text) ? 1.0 : 0.0;
        });
        e_pw2.changed.connect (() => {
            bool ok = e_user.text != "" && e_pw1.text != "" && (e_pw1.text == e_pw2.text);
            create_btn.sensitive = ok;
            p_icon.opacity = (e_pw1.text != "" && e_pw1.text == e_pw2.text) ? 1.0 : 0.0;
        });

        d.get_content_area ().add (grid);
        d.show_all ();

        if (d.run () == Gtk.ResponseType.OK) {
            string grps = "audio,video,storage,optical,network";
            if (c_adm.active) grps = "wheel," + grps;

            string create_cmd = "useradd -m -s /bin/bash -G %s -c %s %s".printf (
                Shell.quote (grps), Shell.quote (e_disp.text.replace(",", "")), Shell.quote (e_user.text));
            
            string pw_cmd = "echo %s | chpasswd".printf (Shell.quote (e_user.text + ":" + e_pw1.text));
            
            string full_chain = "bash -c '%s && %s".printf (create_cmd, pw_cmd);

            string file = fc.get_filename ();
            if (file != null) {
                string target = "/home/%s/.face".printf (e_user.text);
                string cp_cmd = "cp %s %s && chown %s %s && chmod 0644 %s".printf (
                    Shell.quote (file), Shell.quote (target), Shell.quote (e_user.text), Shell.quote (target), Shell.quote (target));
                
                string uid_cmd = "id -u " + Shell.quote (e_user.text);
                string dbus_cmd = "busctl call org.freedesktop.Accounts /org/freedesktop/Accounts/User$(%s) org.freedesktop.Accounts.User SetIconFile s %s".printf (uid_cmd, Shell.quote (target));
                
                full_chain += " && %s && %s".printf (cp_cmd, dbus_cmd);
            }
            
            full_chain += "'";

            if (cmd_auth (full_chain)) {
                reload_users ();
                reselect (e_user.text);
            } else {
                warn ("Failed to create user or set credentials.");
            }
        }
        d.destroy ();
    }

    private void show_password_dialog () {
        if (current == null) return;
        
        bool is_self = (current.name == current_username);

        var d = new Gtk.Dialog.with_buttons (
            "Change Password", this.get_toplevel () as Gtk.Window,
            Gtk.DialogFlags.MODAL,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Apply", Gtk.ResponseType.OK);
        var apply = d.get_widget_for_response (Gtk.ResponseType.OK);
        apply.get_style_context ().add_class ("suggested-action");
        apply.sensitive = false;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12; grid.row_spacing = 14; grid.margin = 20;

        int row = 0;
        Gtk.Entry? e_old = null;
        
        if (is_self) {
            grid.attach (new Gtk.Label ("Current Password:"), 0, row, 1, 1);
            e_old = new Gtk.Entry (); e_old.visibility = false; grid.attach (e_old, 1, row, 1, 1); e_old.hexpand = true;
            row++;
        }

        grid.attach (new Gtk.Label ("New Password:"), 0, row, 1, 1);
        var e_p1 = new Gtk.Entry (); e_p1.visibility = false; grid.attach (e_p1, 1, row, 1, 1); e_p1.hexpand = true;
        row++;

        grid.attach (new Gtk.Label ("Confirm:"), 0, row, 1, 1);
        
        var bx = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        var e_p2 = new Gtk.Entry (); e_p2.visibility = false; e_p2.hexpand = true;
        var p_ic = new Gtk.Image.from_icon_name ("dialog-ok-symbolic", Gtk.IconSize.MENU);
        p_ic.get_style_context ().add_class ("success-icon");
        p_ic.opacity = 0;
        bx.pack_start (e_p2, true, true, 0); bx.pack_start (p_ic, false, false, 0);
        grid.attach (bx, 1, row, 1, 1);

        e_p1.changed.connect (() => {
            bool ok = e_p1.text != "" && e_p1.text == e_p2.text;
            if (is_self && e_old != null) ok = ok && e_old.text != "";
            apply.sensitive = ok;
            p_ic.opacity = ok && e_p1.text != "" ? 1.0 : 0.0;
        });
        e_p2.changed.connect (() => {
            bool ok = e_p1.text != "" && e_p1.text == e_p2.text;
            if (is_self && e_old != null) ok = ok && e_old.text != "";
            apply.sensitive = ok;
            p_ic.opacity = ok && e_p1.text != "" ? 1.0 : 0.0;
        });
        
        if (is_self && e_old != null) {
            e_old.changed.connect (() => {
                bool ok = e_p1.text != "" && e_p1.text == e_p2.text && e_old.text != "";
                apply.sensitive = ok;
            });
        }

        d.get_content_area ().add (grid);
        d.show_all ();

        if (d.run () == Gtk.ResponseType.OK) {
            if (is_self && e_old != null) {
                string? o = cmd_sync ("printf '%%s\\n' %s %s %s | passwd".printf(
                    Shell.quote(e_old.text), Shell.quote(e_p1.text), Shell.quote(e_p1.text)));
                if (o == null || "Authentication failure" in o || "unchanged" in o) {
                    warn ("Failed to change password. Please check your current password.");
                }
            } else {
                cmd_auth ("bash -c 'echo %s | chpasswd'".printf (
                    Shell.quote (current.name + ":" + e_p1.text)));
            }
        }
        d.destroy ();
    }

    private void show_delete_dialog () {
        if (current == null) return;

        var d = new Gtk.MessageDialog (this.get_toplevel () as Gtk.Window, Gtk.DialogFlags.MODAL,
            Gtk.MessageType.WARNING, Gtk.ButtonsType.NONE,
            "Delete user %s?", current.display);
        d.secondary_text = "This action cannot be undone.";

        var cx = new Gtk.CheckButton.with_label ("Remove home directory");
        cx.margin_top = 10;
        d.get_content_area ().add (cx);

        d.add_button ("_Cancel", Gtk.ResponseType.CANCEL);
        var db = d.add_button ("_Delete", Gtk.ResponseType.OK);
        db.get_style_context ().add_class ("destructive-action");
        d.show_all ();

        if (d.run () == Gtk.ResponseType.OK) {
            if (cmd_auth ("userdel %s %s".printf (cx.active ? "-r" : "", Shell.quote (current.name)))) {
                reload_users ();
            } else {
                warn ("Deletion failed. User may be logged in.");
            }
        }
        d.destroy ();
    }

    private void reselect (string un) {
        for (int i = 0; ; i++) {
            var r = list.get_row_at_index (i);
            if (r == null) break;
            if (((UserRow) r).info.name == un) {
                list.select_row (r);
                break;
            }
        }
    }

    private bool cmd_auth (string cmd) {
        int st;
        try {
            Process.spawn_command_line_sync ("pkexec " + cmd, null, null, out st);
            return st == 0;
        } catch (Error e) { return false; }
    }

    private string? cmd_sync (string cmd) {
        int st; string o;
        try {
            Process.spawn_command_line_sync ("bash -c " + Shell.quote (cmd), out o, null, out st);
            return (st == 0) ? o.strip () : null;
        } catch (Error e) { return null; }
    }

    private void warn (string msg) {
        var d = new Gtk.MessageDialog (this.get_toplevel () as Gtk.Window, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.OK, "%s", msg);
        d.run (); d.destroy ();
    }
}

int main (string[] args) {
    if (Environment.get_user_name () == "root") {
        print ("Please run as standard user, polkit handles escalation dynamically.\n");
        return 1;
    }
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

    var w = new UserManager ();
    w.vexpand = true;
    w.hexpand = true;

    if (socket_id != 0) {
        var plug = new Gtk.Plug ((X.Window) socket_id);
        plug.destroy.connect (Gtk.main_quit);
        plug.add (w);
        plug.show_all ();
    } else {
        var window = new Gtk.Window ();
        window.title = "Users";
        window.set_default_size (600, 500);
        window.window_position = Gtk.WindowPosition.CENTER;
        window.destroy.connect (Gtk.main_quit);

        window.add (w);
        window.show_all ();
    }

    Gtk.main ();
    return 0;
}
