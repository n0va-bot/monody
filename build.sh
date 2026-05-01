#!/bin/bash

# ── Configuration ───────────────────────────────────────────────────────────

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$PROJ_DIR/work"
OUT_DIR="$PROJ_DIR/out"
REPO_DIR="$PROJ_DIR/prebuilt_repo"
AUR_DIR="$PROJ_DIR/aur_builds"
WEBSITE_FILE="$PROJ_DIR/website/index.html"
ISO_FINAL="$OUT_DIR/monody-x86_64.iso"
GITHUB_REPO="MonodyDev/monody"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

BUILD_MODE=${1:-all}
if [[ "$BUILD_MODE" != "all" && "$BUILD_MODE" != "repo" && "$BUILD_MODE" != "iso" && "$BUILD_MODE" != "custom" && "$BUILD_MODE" != "aur" ]]; then
    echo -e "${RED}[ERROR]${NC} Invalid argument. Use 'custom', 'aur', 'repo', 'iso', or 'all'."
    exit 1
fi

# ── Functions ────────────────────────────────────────────────────────────────

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
header() { echo -e "\n${PURPLE}# $1${NC}"; }

# ── Configuration Generation ───────────────────────────────────────────────

generate_pacman_conf() {
    header "Generating pacman.conf"

    local EXTRA_MIRROR="/etc/pacman.d/mirrorlist"
    if [ -f "/etc/pacman.d/mirrorlist-arch" ]; then
        EXTRA_MIRROR="/etc/pacman.d/mirrorlist-arch"
    fi

    local MIRRORS="Server = https://mirror2.artixlinux.org/\$repo/os/\$arch
Server = https://mirror3.artixlinux.org/repos/\$repo/os/\$arch
Server = https://mirror.netcologne.de/artix-linux/\$repo/os/\$arch
Server = https://mirror.pascalpuffke.de/artix-linux/\$repo/os/\$arch
Server = http://mirrors.redcorelinux.org/artixlinux/\$repo/os/\$arch
Server = https://ftp.halifax.rwth-aachen.de/artixlinux/\$repo/os/\$arch
Server = https://tools.sphnet.in/mirror/artix/\$repo/os/\$arch
Server = https://ftp.uni-bayreuth.de/linux/artix-linux/\$repo/os/\$arch
Server = https://artix.unixpeople.org/repos/\$repo/os/\$arch
Server = https://artix.sakamoto.pl/\$repo/os/\$arch"

    cat > "$PROJ_DIR/pacman.conf" <<EOF
[options]
HoldPkg = pacman glibc
Architecture = auto
ParallelDownloads = 5
SigLevel = Never
LocalFileSigLevel = Optional
NoExtract = usr/share/help/* !usr/share/help/en*
NoExtract = usr/share/gtk-doc/html/*
NoExtract = usr/share/doc/*
NoExtract = usr/share/locale/* !usr/share/locale/en* !usr/share/locale/locale.alias
NoExtract = usr/share/i18n/locales/* !usr/share/i18n/locales/en_*
NoExtract = usr/share/i18n/charmaps/* !usr/share/i18n/charmaps/UTF-8.gz !usr/share/i18n/charmaps/ANSI*
NoExtract = usr/share/man/*
NoExtract = usr/share/info/*
NoExtract = usr/include/*
NoExtract = usr/share/gir-1.0/*
NoExtract = usr/lib/python*/test/*
NoExtract = usr/lib/python*/idlelib/*
NoExtract = usr/lib/firmware/* !usr/lib/firmware/amdgpu/* !usr/lib/firmware/iwlwifi-* !usr/lib/firmware/intel/iwlwifi/* !usr/lib/firmware/rtw89/* !usr/lib/firmware/rtw88/* !usr/lib/firmware/brcm/* !usr/lib/firmware/ath10k/* !usr/lib/firmware/ath9k* !usr/lib/firmware/intel/sof* !usr/lib/firmware/alsa/* !usr/lib/firmware/i915/* !usr/lib/firmware/radeon/* !usr/lib/firmware/nvidia/*
NoExtract = usr/share/icons/Adwaita/* !usr/share/icons/Adwaita/cursors/* !usr/share/icons/Adwaita/index.theme !usr/share/icons/Adwaita/scalable/*
NoExtract = usr/share/icons/Mint-L/*/22* usr/share/icons/Mint-L/*/24* usr/share/icons/Mint-L/*/32* usr/share/icons/Mint-L/*/64* usr/share/icons/Mint-L/*/96* usr/share/icons/Mint-L/*/128* usr/share/icons/Mint-L/*/256* usr/share/icons/Mint-L/*/512*
NoExtract = usr/share/icons/Mint-L/mimetypes/*
NoExtract = usr/share/icons/Mint-L-* !usr/share/icons/Mint-L-Purple/*
NoExtract = usr/share/themes/Mint-L-* !usr/share/themes/Mint-L-Dark/* !usr/share/themes/Mint-L-Darker/* !usr/share/themes/Mint-L-Purple/* !usr/share/themes/Mint-L-Dark-Purple/* !usr/share/themes/Mint-L-Darker-Purple/*
NoExtract = usr/share/backgrounds/* !usr/share/backgrounds/monody* !usr/share/backgrounds/limine*
NoExtract = usr/share/wallpapers/*

[monody]
SigLevel = Optional TrustAll
Server = file://$REPO_DIR

[system]
$MIRRORS

[world]
$MIRRORS

[galaxy]
$MIRRORS

[extra]
Include = $EXTRA_MIRROR
EOF
    success "pacman.conf generated at $PROJ_DIR/pacman.conf"
}

# ── Pre-checks ──────────────────────────────────────────────────────────────

header "Checking Dependencies"
for cmd in mkarchiso repo-add sha256sum git makepkg; do
    command -v "$cmd" >/dev/null 2>&1 || error "$cmd is not installed."
done

success "All dependencies found."

# ── paru ──────────────────────────────────────────────

header "Checking paru"
if ! command -v paru &>/dev/null; then
    log "paru not found, installing from AUR..."
    mkdir -p "$AUR_DIR"
    if [ ! -d "$AUR_DIR/paru" ]; then
        git clone "https://aur.archlinux.org/paru.git" "$AUR_DIR/paru" || error "Failed to clone paru"
    fi
    (
        cd "$AUR_DIR/paru" || exit 1
        makepkg -scC --noconfirm || error "Failed to build paru"
        $SUDO pacman -U --noconfirm *.pkg.tar.zst || error "Failed to install paru"
    )
    success "paru installed successfully."
else
    success "paru is already installed."
fi

header "Preparing Directories"
mkdir -p "$WORK_DIR" "$OUT_DIR" "$REPO_DIR" "$AUR_DIR"
mkdir -p "$PROJ_DIR/airootfs/usr/local/bin"
generate_pacman_conf
success "Directories and configuration ready."

# ── Local Package Build ──────────────────────────────────────────────────────

if [[ "$BUILD_MODE" == "custom" || "$BUILD_MODE" == "all" ]]; then
header "Building Local Packages"
for pkg in monody-tools monody-backgrounds monody-icons monody-welcome monody-distro-config monody-desktop-config monody monody-installer monody-users; do
    log "Building $pkg ..."
    (
        cd "$PROJ_DIR/src/$pkg" || exit 1

        pkgver=$(grep "^pkgver=" PKGBUILD | cut -d= -f2 | tr -d '"' | tr -d "'")
        pkgrel=$(grep "^pkgrel=" PKGBUILD | cut -d= -f2 | tr -d '"' | tr -d "'")

        EXISTING=$(ls "$REPO_DIR/${pkg}-${pkgver}-${pkgrel}-"*.pkg.tar.zst 2>/dev/null | head -1)

        if [[ -f "$EXISTING" ]]; then
            log "  $pkg is up to date ($pkgver-$pkgrel), skipping build."
        else
            rm -f *.pkg.tar.zst
            if [[ "$pkg" == "monody" ]]; then
                makepkg -cCd --noconfirm || error "Failed to build $pkg"
            else
                makepkg -scC --noconfirm || error "Failed to build $pkg"
            fi
            log "  Copying $pkg to local repo ..."
            cp *.pkg.tar.zst "$REPO_DIR/"
        fi
    ) || error "Error processing $pkg"
done

rm -f "$REPO_DIR"/*-debug*.pkg.tar.zst
fi

# ── AUR Package Updates ──────────────────────────────────────────────────────

if [[ "$BUILD_MODE" == "aur" || "$BUILD_MODE" == "all" ]]; then
header "Checking/Cloning AUR Repositories"
AUR_REPOS=(
    "https://aur.archlinux.org/paru.git"
    "https://aur.archlinux.org/topgrade-bin.git"
    "https://aur.archlinux.org/mint-l-theme.git"
    "https://aur.archlinux.org/mint-l-icons.git"
    "https://aur.archlinux.org/badwolf.git"
)

for repo in "${AUR_REPOS[@]}"; do
    repo_name=$(basename "$repo" .git)
    if [ ! -d "$AUR_DIR/$repo_name" ]; then
        log "Cloning $repo_name ..."
        git clone "$repo" "$AUR_DIR/$repo_name" || error "Failed to clone $repo_name"
    fi
done

header "Updating AUR Packages"
for repo in "${AUR_REPOS[@]}"; do
    pkg_name=$(basename "$repo" .git)
    dir="$AUR_DIR/$pkg_name"
    if [ -d "$dir" ]; then
        log "Checking $pkg_name ..."
        (
            cd "$dir" || exit 1

            OLD_REV=$(git rev-parse HEAD 2>/dev/null || echo "none")
            git pull >/dev/null 2>&1
            NEW_REV=$(git rev-parse HEAD 2>/dev/null || echo "none")

            pkgver=$(grep "^pkgver=" PKGBUILD | cut -d= -f2 | tr -d '"' | tr -d "'")
            pkgrel=$(grep "^pkgrel=" PKGBUILD | cut -d= -f2 | tr -d '"' | tr -d "'")

            EXISTING=$(ls "$REPO_DIR/${pkg_name}-${pkgver}-${pkgrel}-"*.pkg.tar.zst 2>/dev/null | head -1)

            if [[ "$OLD_REV" == "$NEW_REV" && -f "$EXISTING" ]]; then
                log "  $pkg_name is up to date ($pkgver-$pkgrel), skipping build."
            else
                log "  Update detected or package missing for $pkg_name. Building..."

                # Auto-install missing makedepends on the host
                _makedeps=($(bash -c 'source PKGBUILD 2>/dev/null; echo "${makedepends[@]}"'))
                if [ ${#_makedeps[@]} -gt 0 ]; then
                    _missing=()
                    for dep in "${_makedeps[@]}"; do
                        dep_name=$(echo "$dep" | sed 's/[<>=].*//')
                        pacman -Qi "$dep_name" &>/dev/null || _missing+=("$dep_name")
                    done
                    if [ ${#_missing[@]} -gt 0 ]; then
                        log "  Installing makedepends: ${_missing[*]}"
                        $SUDO pacman -S --needed --noconfirm "${_missing[@]}" || \
                            paru -S --needed --noconfirm "${_missing[@]}" || \
                            error "Failed to install makedepends for $pkg_name"
                    fi
                fi

                rm -f *.pkg.tar.zst
                if [[ "$pkg_name" == "cogl" || "$pkg_name" == "clutter" ]]; then
                    makepkg -sciC --noconfirm || error "Failed to build $pkg_name"
                else
                    makepkg -scC --noconfirm || error "Failed to build $pkg_name"
                fi
                log "  Copying $pkg_name to local repo ..."
                cp *.pkg.tar.zst "$REPO_DIR/"
            fi
            rm -f *-debug*.pkg.tar.zst
        ) || error "Error processing $pkg_name"
    fi
done

rm -f "$REPO_DIR"/*-debug*.pkg.tar.zst
fi

# ── Local Repository Update ───────────────────────────────────────────────────
if [[ "$BUILD_MODE" == "repo" || "$BUILD_MODE" == "all" ]]; then
(
    cd "$REPO_DIR" || exit 1
    log "Adding packages to the database..."
    rm -f monody.db.tar.gz monody.db monody.files.tar.gz monody.files
    repo-add monody.db.tar.gz *.pkg.tar.zst || error "Failed to update repository database"
)
success "Local repository updated."
fi

# ── ISO Build ────────────────────────────────────────────────────────────────

if [[ "$BUILD_MODE" == "iso" || "$BUILD_MODE" == "all" ]]; then
header "Building Monody ISO"
log "Cleaning old build files..."
$SUDO rm -rf "$WORK_DIR" "$OUT_DIR"

log "Starting mkarchiso (this will take a while)..."
$SUDO mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" -C "$PROJ_DIR/pacman.conf" "$PROJ_DIR" || error "mkarchiso failed"

# ── Rename to stable filename ────────────────────────────────────────────────

header "Renaming ISO"
DATED_ISO=$(ls -t "$OUT_DIR"/monody-*.iso 2>/dev/null | head -1)
[[ -z "$DATED_ISO" ]] && error "No ISO file found in $OUT_DIR"

$SUDO mv "$DATED_ISO" "$ISO_FINAL"
success "Renamed to $(basename "$ISO_FINAL")"

# ── Checksum ─────────────────────────────────────────────────────────────────

header "Post-Build Tasks"
log "Calculating checksum for $(basename "$ISO_FINAL") ..."
SHA256=$(sha256sum "$ISO_FINAL" | cut -d' ' -f1)
echo "$SHA256  $(basename "$ISO_FINAL")" | $SUDO tee "${ISO_FINAL%.iso}.sha256" > /dev/null
success "SHA256: $SHA256"

ISO_SIZE=$(du -h "$ISO_FINAL" | cut -f1)

# ── Summary ──────────────────────────────────────────────────────────────────

ISO_BYTES=$(stat -c%s "$ISO_FINAL")
LIMIT_BYTES=734003200 # 700 MiB

header "Build Summary"
success "ISO:    $(basename "$ISO_FINAL")"
success "Size:   $ISO_SIZE"
success "SHA256: $SHA256"

if [ "$ISO_BYTES" -gt "$LIMIT_BYTES" ]; then
    echo -e "${RED}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║ WARNING: ISO SIZE EXCEEDS 700MB CD LIMIT!            ║${NC}"
    echo -e "${RED}║ Current size: $ISO_SIZE                                   ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
else
    echo ""
fi
fi

success "Done!"
