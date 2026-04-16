[CCode (cheader_filename = "xfconf/xfconf.h")]
namespace Xfconf {
    [CCode (cname = "xfconf_init")]
    public static bool init () throws GLib.Error;

    [CCode (cname = "xfconf_shutdown")]
    public static void shutdown ();

    [CCode (cname = "XfconfChannel", type_id = "xfconf_channel_get_type ()")]
    public class Channel : GLib.Object {
        [CCode (cname = "xfconf_channel_get")]
        public static unowned Channel get_channel (string channel_name);

        [CCode (cname = "xfconf_channel_get_string")]
        public unowned string get_string (string property, string default_value);

        [CCode (cname = "xfconf_channel_get_int")]
        public int get_int (string property, int default_value);

        [CCode (cname = "xfconf_channel_get_bool")]
        public bool get_bool (string property, bool default_value);

        [CCode (cname = "xfconf_channel_get_double")]
        public double get_double (string property, double default_value);

        [CCode (cname = "xfconf_channel_set_string")]
        public bool set_string (string property, string value);

        [CCode (cname = "xfconf_channel_set_int")]
        public bool set_int (string property, int value);

        [CCode (cname = "xfconf_channel_set_bool")]
        public bool set_bool (string property, bool value);

        [CCode (cname = "xfconf_channel_set_double")]
        public bool set_double (string property, double value);

        public signal void property_changed (string property, GLib.Value value);
    }
}
