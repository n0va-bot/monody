using Gtk;

public errordomain InstallError {
    PARTITION,
    FORMAT,
    MOUNT,
    COPY,
    CONFIG,
    BOOTLOADER,
    GENERAL
}

public class InstallEngine : Object {
    private InstallConfig config;

    public delegate void ProgressCallback (int percent, string message);
    public ProgressCallback progress_callback;

    public delegate void FinishedCallback (bool success, string message);
    public FinishedCallback finished_callback;

    public Utils.LogCallback log_callback;

    public InstallEngine (InstallConfig config) {
        this.config = config;
    }

    private void prog (int pct, string msg) {
        if (progress_callback != null) {
            progress_callback (pct, msg);
        }
    }

    private int run (string cmd) {
        if (log_callback != null) log_callback ("+ " + cmd);
        return Utils.run_async_with_code (cmd, log_callback);
    }

    public void run_install () {
        try {
            string target = "/mnt/monody-target";

            prog (5, "Partitioning " + config.disk + " ...");
            if (!partition_disk ()) throw new InstallError.PARTITION ("Failed to partition disk");

            prog (10, "Formatting & Mounting partitions ...");
            
            string root_dev = "";
            string root_uuid = "";
            string root_fs = "";
            bool root_encrypted = false;
            string root_raw_uuid = "";
            
            run (@"umount -lR $(target) 2>/dev/null || true");

            foreach (PartitionMount pm in config.mounts) {
                if (pm.mount_point == "/") {
                    string dev = pm.device_path;
                    if (pm.format) {
                        if (pm.encrypt) {
                            run (@"printf '%s' '$(config.luks_password)' | cryptsetup luksFormat -q $(dev) -d -");
                            run (@"printf '%s' '$(config.luks_password)' | cryptsetup luksOpen $(dev) monody-root -d -");
                            root_encrypted = true;
                            root_raw_uuid = Utils.run_sync (@"blkid -s UUID -o value $(dev)").strip ();
                            dev = "/dev/mapper/monody-root";
                        }
                        if (pm.filesystem == "btrfs") {
                            if (run (@"mkfs.btrfs -f -L Monody $(dev)") != 0) throw new InstallError.FORMAT ("Failed to format btrfs root");
                        } else {
                            if (run (@"mkfs.ext4 -O ^64bit,^metadata_csum_seed,^metadata_csum,^orphan_file -F -L Monody $(dev)") != 0) throw new InstallError.FORMAT ("Failed to format ext4 root");
                        }
                    } else if (pm.encrypt) {
                        run (@"printf '%s' '$(config.luks_password)' | cryptsetup luksOpen $(dev) monody-root -d -");
                        root_encrypted = true;
                        root_raw_uuid = Utils.run_sync (@"blkid -s UUID -o value $(dev)").strip ();
                        dev = "/dev/mapper/monody-root";
                    }
                    
                    root_dev = dev;
                    root_uuid = Utils.run_sync (@"blkid -s UUID -o value $(dev)").strip ();
                    root_fs = pm.filesystem;
                    break;
                }
            }

            if (root_dev == "") throw new InstallError.MOUNT ("No root partition assigned!");

            run (@"mkdir -p $(target)");
            if (root_fs == "btrfs") {
                run (@"mkdir -p /mnt/btrfs-temp");
                run (@"mount $(root_dev) /mnt/btrfs-temp");
                run (@"btrfs subvolume create /mnt/btrfs-temp/@");
                run (@"btrfs subvolume create /mnt/btrfs-temp/@home");
                run (@"btrfs subvolume create /mnt/btrfs-temp/@cache");
                run (@"btrfs subvolume create /mnt/btrfs-temp/@log");
                run (@"umount /mnt/btrfs-temp");
                
                run (@"mount -o subvol=@ $(root_dev) $(target)");
                run (@"mkdir -p $(target)/home $(target)/var/cache $(target)/var/log");
                run (@"mount -o subvol=@home $(root_dev) $(target)/home");
                run (@"mount -o subvol=@cache $(root_dev) $(target)/var/cache");
                run (@"mount -o subvol=@log $(root_dev) $(target)/var/log");
            } else {
                run (@"mount $(root_dev) $(target)");
            }

            foreach (PartitionMount pm in config.mounts) {
                if (pm.mount_point == "/") continue;
                
                string dev = pm.device_path;
                if (pm.format) {
                    if (pm.filesystem == "vfat") {
                        if (run (@"mkfs.fat -F 32 $(dev)") != 0) throw new InstallError.FORMAT ("Failed to format boot");
                    } else if (pm.filesystem == "ext4") {
                        run (@"mkfs.ext4 -O ^64bit,^metadata_csum_seed,^metadata_csum,^orphan_file -F $(dev)");
                    } else if (pm.filesystem == "btrfs") {
                        run (@"mkfs.btrfs -f $(dev)");
                    } else if (pm.filesystem == "swap" || pm.mount_point == "[SWAP]") {
                        run (@"mkswap $(dev)");
                    }
                }
                
                if (pm.mount_point != "" && pm.mount_point != "[SWAP]") {
                    run (@"mkdir -p $(target)$(pm.mount_point)");
                    run (@"mount $(dev) $(target)$(pm.mount_point)");
                } else if (pm.mount_point == "[SWAP]") {
                    run (@"swapon $(dev)");
                }
                
                if (pm.mount_point == "/boot") {
                    config.boot_part = pm.device_path;
                }
            }

            prog (20, "Copying system files ...");
            string rsync_cmd = @"rsync -aAX --info=progress2 / $(target)/ --exclude=/dev/* --exclude=/proc/* --exclude=/sys/* --exclude=/tmp/* --exclude=/run/* --exclude=/mnt/* --exclude=/media/* --exclude=/lost+found --exclude=$(target) --exclude=/etc/fstab";
            if (Utils.run_async_with_code (rsync_cmd, (line) => {
                if (log_callback != null) log_callback (line);
                if (line.contains ("%")) {
                    try {
                        var regex = new GLib.Regex ("([0-9]+)%");
                        GLib.MatchInfo match_info;
                        if (regex.match (line, 0, out match_info)) {
                            int pct = int.parse (match_info.fetch (1));
                            int mapped = 20 + (int)((pct / 100.0) * 30.0);
                            prog (mapped, "Copying system files ... " + pct.to_string() + "%");
                        }
                    } catch (Error e) {}
                }
            }) != 0) throw new InstallError.COPY ("Failed to copy system files");

            run (@"cp /run/archiso/bootmnt/arch/boot/*-ucode.img $(target)/boot/ 2>/dev/null || true");
            run (@"cp /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux $(target)/boot/vmlinuz-linux 2>/dev/null || true");

            prog (50, "Generating fstab ...");
            string fstab = "# <file system>  <mount point>  <type>  <options>  <dump>  <pass>\n";
            if (root_fs == "btrfs") {
                fstab += @"UUID=$(root_uuid)  /              btrfs   subvol=@,defaults 0 0\n";
                fstab += @"UUID=$(root_uuid)  /home          btrfs   subvol=@home,defaults 0 0\n";
                fstab += @"UUID=$(root_uuid)  /var/cache     btrfs   subvol=@cache,defaults 0 0\n";
                fstab += @"UUID=$(root_uuid)  /var/log       btrfs   subvol=@log,defaults 0 0\n";
            } else {
                fstab += @"UUID=$(root_uuid)  /              ext4    defaults   0 1\n";
            }

            foreach (PartitionMount pm in config.mounts) {
                if (pm.mount_point == "/" || pm.mount_point == "") continue;
                
                string uuid = Utils.run_sync (@"blkid -s UUID -o value $(pm.device_path)").strip ();
                if (pm.mount_point == "[SWAP]") {
                    fstab += @"UUID=$(uuid)  none  swap  defaults  0 0\n";
                } else {
                    string pass = (pm.mount_point == "/boot") ? "2" : "0";
                    fstab += @"UUID=$(uuid)  $(pm.mount_point)  $(pm.filesystem)  defaults  0 $(pass)\n";
                }
            }
            
            GLib.FileUtils.set_contents (target + "/etc/fstab", fstab);

            if (config.swap_size > 0) {
                bool has_swap = false;
                foreach (PartitionMount pm in config.mounts) { if (pm.mount_point == "[SWAP]") has_swap = true; }
                
                if (!has_swap) {
                    prog (55, "Creating swapfile ...");
                    if (root_fs == "btrfs") {
                        run (@"btrfs filesystem mkswapfile --size $(config.swap_size)m $(target)/swapfile");
                    } else {
                        run (@"dd if=/dev/zero of=$(target)/swapfile bs=1M count=$(config.swap_size) status=none");
                        run (@"chmod 0600 $(target)/swapfile");
                        run (@"mkswap $(target)/swapfile");
                    }
                    try {
                        string existing;
                        GLib.FileUtils.get_contents (target + "/etc/fstab", out existing);
                        GLib.FileUtils.set_contents (target + "/etc/fstab", existing + "/swapfile none swap defaults 0 0\n");
                    } catch (Error e) {}
                }
            }

            prog (60, "Configuring system in chroot ...");
            run (@"mount --bind /dev $(target)/dev");
            run (@"mount --bind /dev/pts $(target)/dev/pts");
            run (@"mount -t proc proc $(target)/proc");
            run (@"mount -t sysfs sys $(target)/sys");

            string hooks = "base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck";
            if (root_encrypted) {
                hooks = "base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck";
            }
            string mkinit_conf = @"MODULES=()\nBINARIES=()\nFILES=()\nHOOKS=($(hooks))\nCOMPRESSION=\"zstd\"\n";
            GLib.FileUtils.set_contents (target + "/etc/mkinitcpio.conf", mkinit_conf);
            
            string preset = "ALL_config=\"/etc/mkinitcpio.conf\"\nALL_kver=\"/boot/vmlinuz-linux\"\nPRESETS=('default')\ndefault_image=\"/boot/initramfs-linux.img\"\n";
            GLib.FileUtils.set_contents (target + "/etc/mkinitcpio.d/linux.preset", preset);
            
            run (@"rm -rf $(target)/etc/mkinitcpio.conf.d");

            string script = @"
ln -sf /usr/share/zoneinfo/$(config.timezone) /etc/localtime
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo 'KEYMAP=$(config.keymap)' > /etc/vconsole.conf
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<KEYBOARD
Section \"InputClass\"
        Identifier \"system-keyboard\"
        MatchIsKeyboard \"on\"
        Option \"XkbLayout\" \"$(config.keymap)\"
EndSection
KEYBOARD

echo '$(config.hostname)' > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $(config.hostname)
HOSTS

userdel -rf live 2>/dev/null || true
useradd -m -G wheel,audio,video,storage,optical,network -s /bin/bash -c '$(config.display_name)' '$(config.username)'
echo '$(config.username):$(config.user_pass)' | chpasswd
";
            if (config.root_pass != "") {
                script += @"echo 'root:$(config.root_pass)' | chpasswd\n";
            } else {
                script += "passwd -l root\n";
            }
            script += @"
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

rm -f /etc/sudoers.d/live
rm -f /home/$(config.username)/.bash_profile

mkdir -p /home/$(config.username)/.config/autostart
cp /usr/share/applications/monody-welcome.desktop /home/$(config.username)/.config/autostart/ 2>/dev/null || true
chmod +x /home/$(config.username)/.config/autostart/monody-welcome.desktop 2>/dev/null || true
chown -R $(config.username):$(config.username) /home/$(config.username)/.config

ln -sf /etc/runit/sv/lightdm /etc/runit/runsvdir/default/ 2>/dev/null || true
rm -f /etc/lightdm/lightdm.conf.d/autologin.conf

for tty in tty1 tty2; do
    if [[ -d /etc/runit/sv/agetty-$$tty ]]; then
        ln -sf /etc/runit/sv/agetty-$$tty /etc/runit/runsvdir/default/ 2>/dev/null || true
    fi
done

ln -sf /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/ 2>/dev/null || true
ln -sf /etc/runit/sv/elogind        /etc/runit/runsvdir/default/ 2>/dev/null || true

pacman-key --init
pacman-key --populate artix archlinux

pacman -Rns --noconfirm monody-installer || true
rm -f /home/$(config.username)/.config/autostart/monody-installer.desktop
rm -f /home/$(config.username)/Desktop/monody-install.desktop
rm -f /home/$(config.username)/Desktop/monody-installer.desktop
rm -f /etc/skel/.config/autostart/monody-installer.desktop
rm -f /etc/skel/Desktop/monody-install.desktop
rm -f /etc/skel/Desktop/monody-installer.desktop

mkinitcpio -P
";

            GLib.FileUtils.set_contents (target + "/tmp/chroot.sh", script);
            run (@"chroot $(target) /bin/bash /tmp/chroot.sh");

            prog (80, "Installing bootloader ...");

            string cmdline = @"root=UUID=$(root_uuid) rw quiet splash";
            if (root_encrypted) {
                cmdline = @"cryptdevice=UUID=$(root_raw_uuid):monody-root root=/dev/mapper/monody-root rw quiet splash";
            }
            if (root_fs == "btrfs") {
                cmdline += " rootflags=subvol=@";
            }

            string limine_conf = @"timeout: 5
wallpaper: boot():/limine-bg.png
wallpaper_style: centered
backdrop: 1a1b26
interface_branding: Monody Linux
interface_branding_colour: 4
term_palette: 1a1b26;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;a9b1d6
term_palette_bright: 414868;ff7a93;b9f27c;ff9e64;7aa2f7;dbb6fd;0db9d7;c0caf5
term_margin: 20

/Monody Linux
    protocol: linux
    kernel_path: boot():/vmlinuz-linux
    kernel_cmdline: $(cmdline)
    module_path: boot():/initramfs-linux.img
";

            if (config.boot_mode == "uefi") {
                run (@"mkdir -p $(target)/boot/EFI/BOOT");
                run (@"cp /usr/share/limine/BOOTX64.EFI $(target)/boot/EFI/BOOT/BOOTX64.EFI");
                run (@"cp $(target)/usr/share/backgrounds/limine-bg.png $(target)/boot/limine-bg.png 2>/dev/null || true");
                
                GLib.FileUtils.set_contents (target + "/boot/limine.conf", limine_conf);
                
                string num = config.boot_part.substring (config.boot_part.length - 1);
                run (@"efibootmgr | grep -i 'Monody' | grep -o 'Boot[0-9A-F]*' | sed 's/Boot//' | xargs -r -I{} efibootmgr -b {} -B");
                run (@"efibootmgr -c -d $(config.disk) -p $(num) -l '\\EFI\\BOOT\\BOOTX64.EFI' -L 'Monody Linux'");
            } else {
                run (@"mkdir -p $(target)/boot/limine");
                run (@"cp /usr/share/limine/limine-bios.sys $(target)/boot/limine/");
                run (@"cp $(target)/usr/share/backgrounds/limine-bg.png $(target)/boot/limine-bg.png 2>/dev/null || true");
                GLib.FileUtils.set_contents (target + "/boot/limine/limine.conf", limine_conf);
                run (@"limine bios-install $(config.disk)");
            }

            prog (95, "Cleanup ...");
            run (@"umount -l $(target)/dev/pts 2>/dev/null || true");
            run (@"umount -l $(target)/dev 2>/dev/null || true");
            run (@"umount -l $(target)/proc 2>/dev/null || true");
            run (@"umount -l $(target)/sys 2>/dev/null || true");
            run (@"umount -lR $(target) 2>/dev/null || true");
            if (root_encrypted) run (@"cryptsetup luksClose monody-root 2>/dev/null || true");

            prog (100, "Done");
            if (finished_callback != null) finished_callback (true, "Installation complete!");

        } catch (InstallError e) {
            if (finished_callback != null) finished_callback (false, e.message);
        } catch (GLib.FileError e) {
            if (finished_callback != null) finished_callback (false, "File error: " + e.message);
        }
    }

    private bool partition_disk () {
        if (config.partition_mode == "manual") {
            return true;
        }

        run (@"wipefs -af $(config.disk)");
        run (@"sgdisk -Z $(config.disk)");

        if (config.boot_mode == "uefi") {
            run (@"sgdisk -n 1:0:+512M -t 1:ef00 -c 1:'EFI' $(config.disk)");
            run (@"sgdisk -n 2:0:0 -t 2:8300 -c 2:'Monody' $(config.disk)");
        } else {
            try {
                string cmds = "o\nn\np\n1\n\n+512M\nt\nc\na\nn\np\n2\n\n\nw\n";
                GLib.FileUtils.set_contents ("/tmp/fdisk.in", cmds);
            } catch (GLib.FileError e) {
                warning ("Could not write fdisk input: %s", e.message);
                return false;
            }
            run (@"bash -c 'fdisk $(config.disk) < /tmp/fdisk.in'");
        }
        
        run (@"partprobe $(config.disk)");
        GLib.Thread.usleep (1000000);

        string part_suffix = config.disk.contains ("nvme") ? "p" : "";
        config.boot_part = config.disk + part_suffix + "1";
        config.root_part = config.disk + part_suffix + "2";
        
        config.mounts = new GLib.List<PartitionMount> ();
        config.mounts.append (new PartitionMount (config.boot_part, "/boot", "vfat", true, false));
        config.mounts.append (new PartitionMount (config.root_part, "/", config.root_fs, true, config.encrypt_root));
        
        return true;
    }
}