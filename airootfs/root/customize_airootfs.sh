#!/bin/bash

# pacman keys
pacman-key --init
pacman-key --populate artix archlinux

# USER SETUP

passwd -d root

chmod +x /etc/skel/Desktop/monody-install.desktop
chmod +x /etc/skel/.config/autostart/*

cp /etc/os-release /usr/lib/os-release
cp /etc/lsb-release /usr/lib/lsb-release 2>/dev/null || true

# Runit does not replace the placeholder machine-id automatically.
if [ "$(cat /etc/machine-id 2>/dev/null)" = "uninitialized" ]; then
  rm -f /etc/machine-id
fi
dbus-uuidgen --ensure=/etc/machine-id
mkdir -p /var/lib/dbus
ln -sf /etc/machine-id /var/lib/dbus/machine-id

groupadd -r autologin || true
id -u live >/dev/null 2>&1 || useradd -m -G wheel,audio,video,storage,optical,network,autologin -s /bin/bash live || true

# Keep a static fallback so tty autologin does not depend on useradd succeeding in the image build chroot.
if ! id -u live >/dev/null 2>&1; then
  grep -q '^live:' /etc/group || echo 'live:x:1000:' >> /etc/group
  grep -q '^live:' /etc/gshadow && sed -i '/^live:/d' /etc/gshadow
  [ -f /etc/gshadow ] && echo 'live:!*::' >> /etc/gshadow

  for grp in wheel audio video storage optical network autologin; do
    if grep -q "^${grp}:" /etc/group; then
      sed -i "/^${grp}:/ { /,live\(,\|$\)/! s/$/,live/; }" /etc/group
      if [ -f /etc/gshadow ]; then
        sed -i "/^${grp}:/ { /:.*:.*:.*live\(,\|$\)/! s/$/,live/; }" /etc/gshadow
      fi
    fi
  done

  echo 'live:x:1000:1000:live:/home/live:/bin/bash' >> /etc/passwd
  echo 'live::19000:0:99999:7:::' >> /etc/shadow
fi

mkdir -p /home/live
passwd -d live || true

chown -R live:live /home/live/.config

# Services
rm -f /etc/runit/runsvdir/default/agetty-autologin-tty1
ln -sf /etc/runit/sv/dbus /etc/runit/runsvdir/default/dbus
ln -sf /etc/runit/sv/lightdm /etc/runit/runsvdir/default/lightdm

# STRIPPING

# Locales
find /usr/share/locale -mindepth 1 -maxdepth 1 \
  ! -name 'en_US' ! -name 'locale.alias' -exec rm -rf {} +

# Charsets
find /usr/share/i18n/charmaps -mindepth 1 \
  ! -name 'UTF-8*' ! -name 'ISO-8859*' ! -name 'ASCII*' -delete 2>/dev/null

# gconv
find /usr/lib/gconv -mindepth 1 \
  ! -name 'UTF*' ! -name 'UNICODE*' ! -name 'ISO8859*' ! -name 'gconv-modules*' \
  -delete 2>/dev/null

# Documentation
rm -rf /usr/share/doc /usr/share/gtk-doc /usr/share/man /usr/share/info

# Dev headers
rm -rf /usr/include

# GObject sources
rm -rf /usr/share/gir-1.0

# Static libs
find /usr/lib -name "*.a" -delete 2>/dev/null

# Python bytecode cache
find /usr -name "__pycache__" -exec rm -rf {} + 2>/dev/null
find /usr -name "*.pyc" -delete 2>/dev/null
find /usr -name "*.pyo" -delete 2>/dev/null

# hwdata
rm -f /usr/share/hwdata/pci.ids.gz
rm -f /usr/share/hwdata/oui.txt
rm -f /usr/share/hwdata/iab.txt

# Themes
rm -rf /usr/share/themes/Adwaita
rm -rf /usr/share/themes/Bright
rm -rf /usr/share/themes/Daloa
rm -rf /usr/share/themes/Default-hdpi
rm -rf /usr/share/themes/Default-xhdpi
rm -rf /usr/share/themes/Emacs
rm -rf /usr/share/themes/HighContrast
rm -rf /usr/share/themes/Kokodi
rm -rf /usr/share/themes/Moheli
rm -rf /usr/share/themes/Retro
rm -rf /usr/share/themes/Smoke
rm -rf /usr/share/themes/XP-Balloon
rm -rf /usr/share/themes/ZOMG-PONIES!

# Icons
for d in /usr/share/themes/Mint-L-*/; do
  case "$(basename "$d")" in
    Mint-L-Dark|Mint-L-Darker) ;;
    Mint-L-Purple|Mint-L-Dark-Purple|Mint-L-Darker-Purple) ;;
    *) rm -rf "$d" ;;
  esac
done

rm -rf /usr/share/icons/Papirus
rm -rf /usr/share/icons/Papirus-Dark
rm -rf /usr/share/icons/Papirus-Light
rm -rf /usr/share/icons/AdwaitaLegacy
rm -rf /usr/share/icons/HighContrast

for d in /usr/share/icons/Mint-L-*/; do
  case "$(basename "$d")" in
    Mint-L-Purple) ;;
    *) rm -rf "$d" ;;
  esac
done

# Fonts
rm -rf /usr/share/fonts/Adwaita

# Firmware

# Intel
find /usr/lib/firmware/intel -mindepth 1 -maxdepth 1 \
  ! -name 'i915' ! -name 'xe' ! -name 'iwlwifi' -exec rm -rf {} +
# Remove heavy intel uncompressed binaries and SOF audio
rm -f /usr/lib/firmware/i915/*guc* /usr/lib/firmware/i915/*huc* 2>/dev/null || true
rm -rf /usr/lib/firmware/intel/sof* /usr/lib/firmware/intel/avs* /usr/lib/firmware/intel/ipu* /usr/lib/firmware/intel/vpu*
rm -rf /usr/lib/firmware/intel/catpt*

# Intel WiFi remove legacy chipsets
for legacy in 3945 4965 100 1000 105 135 2000 2030 5000 5150 6000 6000g2a 6000g2b 6050; do
  rm -f /usr/lib/firmware/intel/iwlwifi/iwlwifi-${legacy}-* 2>/dev/null
  rm -f /usr/lib/firmware/iwlwifi-${legacy}-* 2>/dev/null
done

# Intel WiFi keep only the latest firmware version
declare -A latest
for f in /usr/lib/firmware/intel/iwlwifi/iwlwifi-*.ucode.zst; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  variant=$(echo "$base" | sed "s/-[0-9]*\.ucode\.zst$//")
  ver=$(echo "$base" | grep -oP "(?<=-)\d+(?=\.ucode\.zst$)")
  [ -z "$ver" ] && continue
  if [ -z "${latest[$variant]}" ] || [ "$ver" -gt "${latest[$variant]}" ]; then
    latest[$variant]=$ver
  fi
done
for f in /usr/lib/firmware/intel/iwlwifi/iwlwifi-*.ucode.zst; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  variant=$(echo "$base" | sed "s/-[0-9]*\.ucode\.zst$//")
  ver=$(echo "$base" | grep -oP "(?<=-)\d+(?=\.ucode\.zst$)")
  [ -z "$ver" ] && continue
  if [ "$ver" != "${latest[$variant]}" ]; then
    rm -f "$f"
  fi
done


# Clean up dangling top-level iwlwifi symlinks
find /usr/lib/firmware -maxdepth 1 -name 'iwlwifi-*' -type l ! -exec test -e {} \; -delete 2>/dev/null

# AMD GPU
find /usr/lib/firmware/amdgpu -name 'fiji_*' -o -name 'tonga_*' \
  -o -name 'topaz_*' -o -name 'iceland_*' \
  -o -name 'bonaire_*' -o -name 'hainan_*' \
  -o -name 'hawaii_*' -o -name 'kaveri_*' \
  -o -name 'kabini_*' -o -name 'mullins_*' \
  -o -name 'polaris10_*' -o -name 'polaris11_*' -o -name 'polaris12_*' \
  -o -name 'vegam_*' -o -name 'vega10_*' -o -name 'vega12_*' -o -name 'vega20_*' \
  -o -name 'navi10_*' -o -name 'navi12_*' -o -name 'navi14_*' \
  -o -name 'navy_flounder_*' -o -name 'dimgrey_cavefish_*' \
  -o -name 'beige_goby_*' | xargs rm -f 2>/dev/null

rm -f /usr/lib/firmware/amdgpu/gc_* /usr/lib/firmware/amdgpu/smu_*
rm -f /usr/lib/firmware/amdgpu/dcn_* /usr/lib/firmware/amdgpu/psp_*
rm -f /usr/lib/firmware/amdgpu/vce_* /usr/lib/firmware/amdgpu/uvd_*
rm -rf /usr/lib/firmware/amdgpu/aldebaran_*
rm -rf /usr/lib/firmware/amdgpu/banks_*
rm -rf /usr/lib/firmware/amdgpu/cyan_skillfish*
rm -rf /usr/lib/firmware/amdgpu/green_sardine*
rm -rf /usr/lib/firmware/amdgpu/yellow_carp*
rm -rf /usr/lib/firmware/amdgpu/vangogh*
rm -rf /usr/lib/firmware/amdgpu/renoir*
rm -rf /usr/lib/firmware/amdgpu/picasso*
rm -rf /usr/lib/firmware/amdgpu/raven*

# Qualcomm x86 SoC
rm -rf /usr/lib/firmware/qcom

# ath10k - router/phone chips
rm -rf /usr/lib/firmware/ath10k/WCN3990
rm -rf /usr/lib/firmware/ath10k/QCA9984
rm -rf /usr/lib/firmware/ath10k/QCA9888
rm -rf /usr/lib/firmware/ath10k/QCA4019
rm -rf /usr/lib/firmware/ath10k/QCA988X
rm -rf /usr/lib/firmware/ath10k/QCA99X0
rm -rf /usr/lib/firmware/ath10k/QCA9887

# ath11k - router/phone chips
rm -rf /usr/lib/firmware/ath11k/IPQ5018
rm -rf /usr/lib/firmware/ath11k/IPQ6018
rm -rf /usr/lib/firmware/ath11k/IPQ8074
rm -rf /usr/lib/firmware/ath11k/QCN9074
rm -rf /usr/lib/firmware/ath11k/WCN6750

# Old Atheros USB WiFi
rm -rf /usr/lib/firmware/ath6k
rm -rf /usr/lib/firmware/ar3k
rm -f /usr/lib/firmware/ar9170-1.fw.zst
rm -f /usr/lib/firmware/ar5523.bin.zst
rm -f /usr/lib/firmware/htc_7010.fw.zst
rm -f /usr/lib/firmware/ar7010_1_1.fw.zst
rm -f /usr/lib/firmware/ar7010.fw.zst

# Marvell
rm -rf /usr/lib/firmware/mrvl
rm -rf /usr/lib/firmware/mwlwifi
rm -rf /usr/lib/firmware/mwl8k
rm -rf /usr/lib/firmware/libertas

# Enterprise/datacenter NICs
rm -rf /usr/lib/firmware/bnx2x
rm -rf /usr/lib/firmware/bnx2
rm -rf /usr/lib/firmware/liquidio
rm -rf /usr/lib/firmware/netronome
rm -rf /usr/lib/firmware/mellanox
rm -rf /usr/lib/firmware/qlogic
rm -rf /usr/lib/firmware/ql2*
rm -rf /usr/lib/firmware/cxgb4
rm -rf /usr/lib/firmware/slicoss*
rm -rf /usr/lib/firmware/tehuti*
rm -f /usr/lib/firmware/hfi1_pcie.fw.zst

# TV/DVB tuners
rm -rf /usr/lib/firmware/dvb-*
rm -rf /usr/lib/firmware/av7110*
rm -rf /usr/lib/firmware/go7007
rm -rf /usr/lib/firmware/tlg2300*

# WiGig
rm -rf /usr/lib/firmware/wil6210*

# USB serial adapters
rm -rf /usr/lib/firmware/keyspan*
rm -rf /usr/lib/firmware/edgeport
rm -rf /usr/lib/firmware/whiteheat*

# Obscure/legacy devices
rm -rf /usr/lib/firmware/dabusb*
rm -rf /usr/lib/firmware/vicam*
rm -rf /usr/lib/firmware/kaweth*
rm -rf /usr/lib/firmware/sb16
rm -rf /usr/lib/firmware/usbdux*
rm -rf /usr/lib/firmware/cis
rm -rf /usr/lib/firmware/liquidio
rm -rf /usr/lib/firmware/netronome
rm -rf /usr/lib/firmware/mellanox
rm -rf /usr/lib/firmware/qlogic
rm -rf /usr/lib/firmware/ql2*
rm -rf /usr/lib/firmware/cxgb4

# Bluetooth
rm -rf /usr/lib/firmware/rtl_bt
rm -rf /usr/lib/firmware/qca

# Kernel modules
find /usr/lib/modules -name "*.ko*.zst" | grep -E \
  "(staging|isdn|hamradio|drivers/infiniband|drivers/media/dvb|drivers/media/pci|sound/isa|drivers/net/ethernet/mellanox|drivers/net/ethernet/intel/ice|drivers/net/ethernet/intel/i40e|drivers/net/ethernet/intel/ixgbe|drivers/net/ethernet/qlogic|drivers/net/ethernet/broadcom/bnx|drivers/net/ethernet/chelsio|drivers/net/ethernet/cisco|drivers/net/ethernet/neterion|drivers/scsi/qla|drivers/scsi/mpt3sas|drivers/scsi/megaraid|drivers/scsi/lpfc|drivers/scsi/bfa|drivers/scsi/smartpqi|drivers/message/fusion)" \
  | xargs rm -f 2>/dev/null

# Miscellaneous
rm -rf /usr/share/games
rm -rf /usr/share/dict
rm -rf /usr/lib/python*/test
rm -rf /usr/lib/python*/idlelib
rm -rf /usr/share/zoneinfo/right
rm -rf /var/cache/pacman/pkg/*

# Fix pacman unknown key %INSTALLED_DB% warnings
find /var/lib/pacman/local -name desc -exec sed -i '/^%INSTALLED_DB%$/,+1d' {} +

# Firefox
rm -rf /usr/lib/firefox/browser/features/*
rm -rf /usr/lib/firefox/crashreporter
rm -rf /usr/lib/firefox/minidump-analyzer
rm -rf /usr/lib/firefox/updater
rm -rf /usr/lib/firefox/browser/chrome/icons/default

# Strip large icons
# Mint-L icons
find /usr/share/icons/Mint-L* -type d -name '*@2x*' -exec rm -rf {} + 2>/dev/null
find /usr/share/icons/Mint-L* -type d -name '64*' -o -name '96*' -o -name '128*' -o -name '256*' -o -name '512*' -exec rm -rf {} + 2>/dev/null

find /usr/share/icons/Adwaita -mindepth 1 -maxdepth 1 ! -name 'cursors' ! -name 'index.theme' ! -name 'scalable' -exec rm -rf {} + 2>/dev/null

rm -rf /usr/lib/firmware/intel/ibt-*
rm -rf /usr/lib/firmware/mediatek
rm -rf /usr/lib/firmware/ti-connectivity
rm -rf /usr/lib/firmware/nxp
rm -rf /usr/lib/firmware/liquidio
rm -rf /usr/lib/firmware/netronome
rm -rf /usr/lib/firmware/cxgb4
rm -rf /usr/lib/firmware/mellanox
rm -rf /usr/lib/firmware/mrvl
rm -rf /usr/lib/firmware/qcom
rm -rf /usr/lib/firmware/brcm/*bt*
rm -rf /usr/lib/firmware/ath11k
rm -rf /usr/lib/firmware/ath12k
rm -rf /usr/lib/firmware/xe


# Clear databases
rm -rf /var/lib/pacman/sync/*

# Clean Help and Docs
rm -rf /usr/share/help

rm -rf /usr/lib/firmware/nvidia

sed -i 's/^Icon=.*/Icon=folder/g' /usr/share/applications/thunar.desktop

gtk-update-icon-cache -f -t /usr/share/icons/Mint-L 2>/dev/null || true
gtk-update-icon-cache -f -t /usr/share/icons/Mint-L-Purple 2>/dev/null || true
dconf update || true

# Rebuild initramfs after firmware stripping
depmod -a

# Fix Grouped Window List middle click behavior
sed -i '/"middle-click-action": {/,/}/ s/"default": 3/"default": 2/' /usr/share/cinnamon/applets/grouped-window-list@cinnamon.org/settings-schema.json

# Fix default keyboard layout and locale
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "KEYMAP=us" > /etc/vconsole.conf
echo "LANG=en_US.UTF-8" > /etc/locale.conf

mkinitcpio -P || true
