#!/bin/bash

# ── Configuration ───────────────────────────────────────────────────────────

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$PROJ_DIR/work"
OUT_DIR="$PROJ_DIR/out"
REPO_DIR="$PROJ_DIR/prebuilt_repo"
AUR_DIR="$PROJ_DIR/aur_builds"
WEBSITE_FILE="$PROJ_DIR/website/index.html"
ISO_FINAL="$OUT_DIR/monody-x86_64.iso"
GITHUB_REPO="n0va-bot/monody"

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
if [[ "$BUILD_MODE" != "all" && "$BUILD_MODE" != "repo" && "$BUILD_MODE" != "iso" ]]; then
    echo -e "${RED}[ERROR]${NC} Invalid argument. Use 'repo', 'iso', or 'all'."
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

header "Preparing Directories"
mkdir -p "$WORK_DIR" "$OUT_DIR" "$REPO_DIR" "$AUR_DIR"
mkdir -p "$PROJ_DIR/airootfs/usr/local/bin"
generate_pacman_conf
success "Directories and configuration ready."

# ── Local Package Build ──────────────────────────────────────────────────────

if [[ "$BUILD_MODE" == "repo" || "$BUILD_MODE" == "all" ]]; then
header "Building Local Packages"
for pkg in monody-file-search-provider monody-hotcorners monody-tools monody monody-installer; do
    log "Building $pkg ..."
    (
        cd "$PROJ_DIR/src/$pkg" || exit 1

        pkgver=$(grep "^pkgver=" PKGBUILD | cut -d= -f2 | tr -d '"' | tr -d "'")
        pkgrel=$(grep "^pkgrel=" PKGBUILD | cut -d= -f2 | tr -d '"' | tr -d "'")

        rm -f *.pkg.tar.zst
        if [[ "$pkg" == "monody" ]]; then
            makepkg -cCd --noconfirm || error "Failed to build $pkg"
        else
            makepkg -scC --noconfirm || error "Failed to build $pkg"
        fi
        log "  Copying $pkg to local repo ..."
        cp *.pkg.tar.zst "$REPO_DIR/"
    ) || error "Error processing $pkg"
done

rm -f "$REPO_DIR"/*-debug*.pkg.tar.zst

# ── AUR Package Updates ──────────────────────────────────────────────────────

header "Checking/Cloning AUR Repositories"
AUR_REPOS=(
    "https://aur.archlinux.org/cogl.git"
    "https://aur.archlinux.org/clutter.git"
    "https://aur.archlinux.org/xfdashboard.git"
    "https://aur.archlinux.org/paru.git"
    "https://aur.archlinux.org/topgrade-bin.git"
    "https://aur.archlinux.org/vala-panel-appmenu.git"
)

for repo in "${AUR_REPOS[@]}"; do
    repo_name=$(basename "$repo" .git)
    if [ ! -d "$AUR_DIR/$repo_name" ]; then
        log "Cloning $repo_name ..."
        git clone "$repo" "$AUR_DIR/$repo_name" || error "Failed to clone $repo_name"
    fi

    if [[ "$repo_name" == "vala-panel-appmenu" ]]; then
        log "  Applying Monody patches to $repo_name/PKGBUILD ..."
        sed -i 's/: ${_build_mate:=true}/: ${_build_mate:=false}/' "$AUR_DIR/$repo_name/PKGBUILD"
        sed -i 's/: ${_build_vala:=true}/: ${_build_vala:=false}/' "$AUR_DIR/$repo_name/PKGBUILD"
        sed -i 's/: ${_build_budgie:=true}/: ${_build_budgie:=false}/' "$AUR_DIR/$repo_name/PKGBUILD"

        if ! grep -q "jayatana=enabled" "$AUR_DIR/$repo_name/PKGBUILD"; then
            sed -i '/-Dauto_features=disabled/a \  -Djayatana=enabled' "$AUR_DIR/$repo_name/PKGBUILD"
            sed -i "s/makedepends=(/makedepends=('java-environment' /" "$AUR_DIR/$repo_name/PKGBUILD"
        fi
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

# ── Local Repository Update ───────────────────────────────────────────────────
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