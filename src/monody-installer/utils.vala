namespace Utils {
    public delegate void LogCallback (string line);

    public string run_sync (string cmd) {
        try {
            string standard_output;
            string standard_error;
            int exit_status;

            Process.spawn_command_line_sync (
                cmd,
                out standard_output,
                out standard_error,
                out exit_status
            );
            return standard_output.strip ();
        } catch (Error e) {
            warning ("Failed to run sync command '%s': %s", cmd, e.message);
            return "";
        }
    }

    public int run_sync_with_code (string cmd) {
        try {
            int exit_status;
            Process.spawn_command_line_sync (
                cmd,
                null,
                null,
                out exit_status
            );
            if (Process.if_exited (exit_status)) {
                return Process.exit_status (exit_status);
            }
            return -1;
        } catch (Error e) {
            warning ("Failed to run sync command '%s': %s", cmd, e.message);
            return -1;
        }
    }

    public int run_async_with_code (string cmd, LogCallback? logger) {
        try {
            var launcher = new GLib.SubprocessLauncher (GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE);
            var process = launcher.spawnv ({"bash", "-c", cmd});
            
            var dis = new GLib.DataInputStream (process.get_stdout_pipe ());

            string line;
            while (true) {
                size_t len;
                line = dis.read_upto ("\r\n", 2, out len, null);
                if (line == null) {
                    break;
                }
                
                dis.read_byte (null);

                if (logger != null) {
                    string clean = line.strip ();
                    if (clean != "") logger (clean);
                }
            }
            
            process.wait ();
            if (process.get_if_exited ()) {
                return process.get_exit_status ();
            }
            return -1;
        } catch (Error e) {
            warning ("Failed to run async command '%s': %s", cmd, e.message);
            if (logger != null) logger ("Error: " + e.message);
            return -1;
        }
    }

    public bool is_uefi () {
        return GLib.FileUtils.test ("/sys/firmware/efi", GLib.FileTest.IS_DIR);
    }
}