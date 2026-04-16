[DBus (name = "org.gnome.Shell.SearchProvider2")]
public class FileSearchProvider : Object {

    private string[] search_dirs;
    private int max_depth;
    private int max_results;
    private bool show_hidden;

    private string home_dir;

    private Xfconf.Channel? channel;

    private string[] default_dirs = {
        "Documents", "Downloads", "Pictures",
        "Music", "Videos", "Desktop"
    };

    public FileSearchProvider () {
        home_dir = Environment.get_home_dir ();

        try {
            Xfconf.init ();
            channel = Xfconf.Channel.get_channel ("monody");
            load_settings ();

            channel.property_changed.connect ((prop, val) => {
                if (prop.has_prefix ("/file-search/")) {
                    load_settings ();
                }
            });
        } catch (Error e) {
            stderr.printf ("xfconf init failed, using defaults: %s\n", e.message);
            search_dirs = default_dirs;
            max_depth = 3;
            max_results = 10;
            show_hidden = false;
        }
    }

    private void load_settings () {
        max_depth = channel.get_int ("/file-search/max-depth", 3);
        max_results = channel.get_int ("/file-search/max-results", 10);
        show_hidden = channel.get_bool ("/file-search/show-hidden", false);

        string dirs_str = channel.get_string ("/file-search/directories", "");
        if (dirs_str == "") {
            search_dirs = default_dirs;
        } else {
            search_dirs = dirs_str.split (";");
        }
    }

    public string[] GetInitialResultSet (string[] terms) throws Error {
        return do_search (terms);
    }

    public string[] GetSubsearchResultSet (string[] previous_results, string[] terms) throws Error {
        return do_search (terms);
    }

    public HashTable<string, Variant>[] GetResultMetas (string[] identifiers) throws Error {
        var metas = new HashTable<string, Variant>[identifiers.length];

        for (int i = 0; i < identifiers.length; i++) {
            var path = identifiers[i];
            var file = File.new_for_path (path);
            var basename = file.get_basename ();
            var parent = file.get_parent ();
            var parent_path = parent != null ? parent.get_path () : home_dir;

            var display_path = parent_path;
            if (display_path.has_prefix (home_dir)) {
                display_path = "~" + display_path.substring (home_dir.length);
            }

            bool uncertain;
            var content_type = ContentType.guess (basename, null, out uncertain);
            var icon = ContentType.get_icon (content_type);
            var icon_str = icon.to_string ();

            var meta = new HashTable<string, Variant> (str_hash, str_equal);
            meta.insert ("id", new Variant.string (path));
            meta.insert ("name", new Variant.string (basename));
            meta.insert ("description", new Variant.string (display_path));
            meta.insert ("gicon", new Variant.string (icon_str));

            metas[i] = meta;
        }

        return metas;
    }

    public void ActivateResult (string identifier, string[] terms, uint32 timestamp) throws Error {
        try {
            AppInfo.launch_default_for_uri (
                File.new_for_path (identifier).get_uri (), null
            );
        } catch (Error e) {
            try {
                Process.spawn_command_line_async ("xdg-open " + Shell.quote (identifier));
            } catch (Error e2) {
                warning ("Failed to open %s: %s", identifier, e2.message);
            }
        }
    }

    public void LaunchSearch (string[] terms, uint32 timestamp) throws Error {
        try {
            Process.spawn_command_line_async ("thunar " + Shell.quote (home_dir));
        } catch (Error e) {
            warning ("Failed to launch Thunar: %s", e.message);
        }
    }

    private string[] do_search (string[] terms) {
        var results = new GenericArray<string> ();
        var query = string.joinv (" ", terms).down ();

        foreach (var dir_name in search_dirs) {
            var dir_path = Path.build_filename (home_dir, dir_name);
            if (dir_name.down ().contains (query)) {
                results.add (dir_path);
            }
            if (results.length >= max_results) break;

            search_directory (dir_path, query, results, 0);
            if (results.length >= max_results) break;
        }

        if (results.length < max_results) {
            search_directory (home_dir, query, results, max_depth);
        }

        var arr = new string[results.length];
        for (int i = 0; i < results.length; i++) {
            arr[i] = results[i];
        }
        return arr;
    }

    private void search_directory (string path, string query, GenericArray<string> results, int depth) {
        if (results.length >= max_results) return;
        if (depth > max_depth) return;

        var dir = File.new_for_path (path);
        FileEnumerator enumerator;

        try {
            enumerator = dir.enumerate_children (
                FileAttribute.STANDARD_NAME + "," +
                FileAttribute.STANDARD_TYPE + "," +
                FileAttribute.STANDARD_IS_HIDDEN,
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                null
            );
        } catch (Error e) {
            return;
        }

        try {
            FileInfo info;
            while ((info = enumerator.next_file (null)) != null) {
                if (results.length >= max_results) break;

                if (!show_hidden && info.get_is_hidden ()) continue;

                var name = info.get_name ();
                var child_path = Path.build_filename (path, name);

                if (name.down ().contains (query)) {
                    results.add (child_path);
                }
                if (results.length >= max_results) break;

                if (info.get_file_type () == FileType.DIRECTORY) {
                    search_directory (child_path, query, results, depth + 1);
                }
            }
        } catch (Error e) { }
    }
}

void on_bus_acquired (DBusConnection conn) {
    try {
        conn.register_object ("/org/monody/FileSearch", new FileSearchProvider ());
    } catch (IOError e) {
        stderr.printf ("Could not register D-Bus object: %s\n", e.message);
    }
}

int main (string[] args) {
    var loop = new MainLoop ();

    Bus.own_name (
        BusType.SESSION,
        "org.monody.FileSearch",
        BusNameOwnerFlags.NONE,
        on_bus_acquired,
        () => {},
        () => {
            stderr.printf ("Could not acquire D-Bus name\n");
            loop.quit ();
        }
    );

    loop.run ();
    return 0;
}