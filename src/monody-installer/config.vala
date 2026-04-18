public class PartitionMount : Object {
    public string device_path { get; set; }
    public string mount_point { get; set; }
    public string filesystem { get; set; }
    public bool format { get; set; }
    public bool encrypt { get; set; }

    public PartitionMount (string device_path, string mount_point, string filesystem, bool format, bool encrypt = false) {
        this.device_path = device_path;
        this.mount_point = mount_point;
        this.filesystem = filesystem;
        this.format = format;
        this.encrypt = encrypt;
    }
}

public class InstallConfig : Object {
    public string disk { get; set; default = ""; }
    public string boot_mode { get; set; default = "bios"; }
    public string timezone { get; set; default = "UTC"; }
    public string hostname { get; set; default = "monody"; }
    public string display_name { get; set; default = ""; }
    public string username { get; set; default = "monody"; }
    public string user_pass { get; set; default = ""; }
    public string root_pass { get; set; default = ""; }
    public string keymap { get; set; default = "us"; }
    public string partition_mode { get; set; default = "auto"; }
    
    public string root_fs { get; set; default = "btrfs"; }
    public bool encrypt_root { get; set; default = false; }
    public string luks_password { get; set; default = ""; }
    public int swap_size { get; set; default = 512; }

    public string boot_part { get; set; default = ""; }
    public string root_part { get; set; default = ""; }

    public GLib.List<PartitionMount> mounts = new GLib.List<PartitionMount> ();
}