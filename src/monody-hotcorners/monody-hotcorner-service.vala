using Gtk;
using Gdk;
using GLib;


public enum CornerAction {
    NONE,
    XFDASHBOARD,
    SHOW_DESKTOP,
    CUSTOM_COMMAND;

    public static CornerAction from_string (string s) {
        switch (s.down ()) {
            case "xfdashboard": return XFDASHBOARD;
            case "show-desktop": return SHOW_DESKTOP;
            case "custom-command": return CUSTOM_COMMAND;
            default: return NONE;
        }
    }

    public string to_string_value () {
        switch (this) {
            case XFDASHBOARD: return "xfdashboard";
            case SHOW_DESKTOP: return "show-desktop";
            case CUSTOM_COMMAND: return "custom-command";
            default: return "none";
        }
    }
}

public enum Corner {
    TOP_LEFT,
    TOP_RIGHT,
    BOTTOM_LEFT,
    BOTTOM_RIGHT;

    public string to_xfconf_path () {
        switch (this) {
            case TOP_LEFT: return "top-left";
            case TOP_RIGHT: return "top-right";
            case BOTTOM_LEFT: return "bottom-left";
            case BOTTOM_RIGHT: return "bottom-right";
            default: return "top-left";
        }
    }
}

public class CornerConfig {
    public CornerAction action;
    public string custom_command;

    public CornerConfig () {
        action = CornerAction.NONE;
        custom_command = "";
    }
}

public class HotcornerService : Object {
    private const int CORNER_SIZE = 2;
    private const int POLL_INTERVAL_MS = 20;
    private const int COOLDOWN_MS = 1000;

    private Xfconf.Channel channel;
    private CornerConfig[] corners;
    private int sensitivity;
    private int pressure_duration;

    private int prev_x = -1;
    private int prev_y = -1;
    private double velocity = 0.0;
    private Corner? active_corner = null;
    private int64 corner_enter_time = 0;
    private bool triggered = false;
    private int64 last_trigger_time = 0;

    private Gdk.Display display;
    private Gdk.Screen screen;

    public HotcornerService () {
        corners = new CornerConfig[4];
        for (int i = 0; i < 4; i++) {
            corners[i] = new CornerConfig ();
        }
    }

    public void start () {
        try {
            Xfconf.init ();
        } catch (Error e) {
            stderr.printf ("Failed to init xfconf: %s\n", e.message);
        }

        channel = new Xfconf.Channel ("monody");
        load_settings ();

        channel.property_changed.connect ((prop, val) => {
            if (prop.has_prefix ("/hotcorners/")) {
                load_settings ();
            }
        });

        display = Gdk.Display.get_default ();
        screen = Gdk.Screen.get_default ();

        GLib.Timeout.add (POLL_INTERVAL_MS, poll_mouse);
    }

    private void load_settings () {
        sensitivity = channel.get_int ("/hotcorners/sensitivity", 5);
        pressure_duration = channel.get_int ("/hotcorners/pressure-duration", 300);

        Corner[] all_corners = {
            Corner.TOP_LEFT, Corner.TOP_RIGHT,
            Corner.BOTTOM_LEFT, Corner.BOTTOM_RIGHT
        };

        for (int i = 0; i < 4; i++) {
            string path = "/hotcorners/" + all_corners[i].to_xfconf_path ();
            string action_str = channel.get_string (
                path + "/action", "none");
            string cmd = channel.get_string (
                path + "/command", "");
            corners[i].action = CornerAction.from_string (action_str);
            corners[i].custom_command = cmd;
        }
    }

    private bool poll_mouse () {
        int x, y;
        Gdk.ModifierType mask;
        var seat = display.get_default_seat ();
        var pointer = seat.get_pointer ();

        Gdk.Window? root_window = screen.get_root_window ();
        if (root_window == null) return true;

        root_window.get_device_position (pointer, out x, out y, out mask);

        int sw = screen.get_width ();
        int sh = screen.get_height ();

        if (prev_x >= 0 && prev_y >= 0) {
            double dx = (double)(x - prev_x);
            double dy = (double)(y - prev_y);
            velocity = Math.sqrt (dx * dx + dy * dy);
        }
        prev_x = x;
        prev_y = y;

        Corner? corner = null;
        if (x <= CORNER_SIZE && y <= CORNER_SIZE) {
            corner = Corner.TOP_LEFT;
        } else if (x >= sw - CORNER_SIZE - 1 && y <= CORNER_SIZE) {
            corner = Corner.TOP_RIGHT;
        } else if (x <= CORNER_SIZE && y >= sh - CORNER_SIZE - 1) {
            corner = Corner.BOTTOM_LEFT;
        } else if (x >= sw - CORNER_SIZE - 1 && y >= sh - CORNER_SIZE - 1) {
            corner = Corner.BOTTOM_RIGHT;
        }

        int64 now = GLib.get_monotonic_time () / 1000;

        if (corner == null) {
            active_corner = null;
            corner_enter_time = 0;
            triggered = false;
            return true;
        }

        if (now - last_trigger_time < COOLDOWN_MS) {
            return true;
        }

        int ci = (int) corner;
        if (corners[ci].action == CornerAction.NONE) {
            return true;
        }

        if (active_corner == null || active_corner != corner) {
            active_corner = corner;
            corner_enter_time = now;
            triggered = false;
        }

        if (triggered) {
            return true;
        }

        double velocity_threshold = 20.0 - (sensitivity * 1.5);
        if (velocity_threshold < 2.0) velocity_threshold = 2.0;

        int adjusted_pressure = (int)(pressure_duration * (11 - sensitivity) / 10.0);
        if (adjusted_pressure < 50) adjusted_pressure = 50;

        int64 linger = now - corner_enter_time;

        bool velocity_ok = velocity >= velocity_threshold;
        bool pressure_ok = linger >= adjusted_pressure;

        if (velocity_ok || pressure_ok) {
            execute_action (corners[ci]);
            triggered = true;
            last_trigger_time = now;
        }

        return true;
    }

    private void execute_action (CornerConfig config) {
        string? cmd = null;

        switch (config.action) {
            case CornerAction.XFDASHBOARD:
                int exit_status = -1;
                try {
                    Process.spawn_command_line_sync ("pgrep -x xfdashboard", null, null, out exit_status);
                    if (Process.if_exited (exit_status) && Process.exit_status (exit_status) == 0) {
                        cmd = "xfdashboard -q";
                    } else {
                        cmd = "xfdashboard";
                    }
                } catch (Error e) {
                    cmd = "xfdashboard";
                }
                break;
            case CornerAction.SHOW_DESKTOP:
                cmd = "wmctrl -k on";
                break;
            case CornerAction.CUSTOM_COMMAND:
                if (config.custom_command != "") {
                    cmd = config.custom_command;
                }
                break;
            default:
                break;
        }

        if (cmd != null) {
            try {
                Process.spawn_command_line_async (cmd);
            } catch (Error e) {
                stderr.printf ("Hotcorner: failed to execute '%s': %s\n",
                               cmd, e.message);
            }
        }
    }
}

int main (string[] args) {
    Gtk.init (ref args);

    var service = new HotcornerService ();
    service.start ();

    Gtk.main ();
    return 0;
}