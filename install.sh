#!/bin/bash
# install.sh - LXC Template Repository Installer
set -euo pipefail

# === Configuration ===
readonly PAGES_URL="https://deroy2112.github.io/proxmox-lxc-templates"
readonly APL_DIR="/var/lib/pve-manager/apl-info"
readonly APL_FILE="proxmox-lxc-templates.dat"
readonly CRON_FILE="/etc/cron.daily/proxmox-lxc-templates-update"

# === Colors ===
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# === Functions ===
info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

cleanup() {
    local exit_code=$?
    rm -rf "${TEMP_DIR:-}"
    exit "$exit_code"
}

# === Main ===
trap cleanup EXIT

info "Checking prerequisites..."

# Root check
[[ $EUID -eq 0 ]] || die "This script must be run as root."

# Proxmox check
command -v pveversion >/dev/null 2>&1 || die "Proxmox VE not found."
[[ -d "$APL_DIR" ]] || die "APL directory not found: $APL_DIR"

info "Proxmox VE $(pveversion | cut -d'/' -f2) detected."

# === Download with checksum verification ===
info "Downloading template index..."

TEMP_DIR=$(mktemp -d)

curl -fsSL "${PAGES_URL}/aplinfo.dat.gz" -o "${TEMP_DIR}/aplinfo.dat.gz" \
    || die "Download of aplinfo.dat.gz failed."

curl -fsSL "${PAGES_URL}/aplinfo.dat.gz.sha256" -o "${TEMP_DIR}/expected.sha256" \
    || die "Download of checksum failed."

# Verify checksum
info "Verifying checksum..."
EXPECTED_HASH=$(cat "${TEMP_DIR}/expected.sha256")
ACTUAL_HASH=$(sha256sum "${TEMP_DIR}/aplinfo.dat.gz" | cut -d' ' -f1)

if [[ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]]; then
    error "Checksum verification failed!"
    error "Expected: $EXPECTED_HASH"
    error "Received: $ACTUAL_HASH"
    die "File may have been tampered with. Installation aborted."
fi

info "Checksum OK: ${ACTUAL_HASH:0:16}..."

# === Installation ===
info "Installing template index..."

gunzip -c "${TEMP_DIR}/aplinfo.dat.gz" > "${APL_DIR}/${APL_FILE}" \
    || die "Decompression failed."

info "Template index installed: ${APL_DIR}/${APL_FILE}"

# === Setup cronjob ===
info "Setting up automatic updates..."

cat > "$CRON_FILE" <<'CRONSCRIPT'
#!/bin/bash
# Auto-update for LXC Templates
set -euo pipefail

readonly PAGES_URL="https://deroy2112.github.io/proxmox-lxc-templates"
readonly APL_DIR="/var/lib/pve-manager/apl-info"
readonly APL_FILE="proxmox-lxc-templates.dat"

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download
curl -fsSL "${PAGES_URL}/aplinfo.dat.gz" -o "${TEMP_DIR}/aplinfo.dat.gz" || exit 1
curl -fsSL "${PAGES_URL}/aplinfo.dat.gz.sha256" -o "${TEMP_DIR}/expected.sha256" || exit 1

# Verify
EXPECTED=$(cat "${TEMP_DIR}/expected.sha256")
ACTUAL=$(sha256sum "${TEMP_DIR}/aplinfo.dat.gz" | cut -d' ' -f1)
[[ "$EXPECTED" == "$ACTUAL" ]] || exit 1

# Install
gunzip -c "${TEMP_DIR}/aplinfo.dat.gz" > "${APL_DIR}/${APL_FILE}"

logger -t lxc-templates "Template index updated"
CRONSCRIPT

chmod +x "$CRON_FILE"
info "Cronjob installed: $CRON_FILE"

# === Done ===
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation successful!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Templates are now available in the Proxmox UI:"
echo "    Datacenter → Storage → local → CT Templates"
echo ""
echo "  Automatic updates: daily via cronjob"
echo ""
echo "  Uninstall:"
echo "    rm ${APL_DIR}/${APL_FILE}"
echo "    rm ${CRON_FILE}"
echo ""
