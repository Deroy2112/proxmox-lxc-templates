#!/bin/bash
# template-update - In-container update tool for LXC templates
set -euo pipefail

readonly VERSION="1.0.0"
readonly TEMPLATE_INFO_FILE="/etc/template-info"
readonly BACKUP_DIR="/var/backups/template-update"
readonly HISTORY_FILE="/var/log/template-update.log"

# === Colors ===
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
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

# Load template info
load_template_info() {
    if [[ ! -f "$TEMPLATE_INFO_FILE" ]]; then
        die "Template info file not found: $TEMPLATE_INFO_FILE"
    fi
    # shellcheck source=/dev/null
    source "$TEMPLATE_INFO_FILE"
}

# Get latest version from GitHub
get_latest_version() {
    local repo_api
    repo_api=$(echo "${TEMPLATE_REPO}" | sed 's|github.com|api.github.com/repos|')

    curl -fsSL "${repo_api}/releases" 2>/dev/null | \
        grep -oP '"tag_name":\s*"v\K[^"]+(?=-'"${TEMPLATE_NAME}"')' | \
        head -1
}

# Show status
cmd_status() {
    load_template_info

    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Template Status${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Name:      ${TEMPLATE_NAME}"
    echo "  Version:   ${TEMPLATE_VERSION}"
    echo "  Repo:      ${TEMPLATE_REPO}"
    echo "  Installed: ${INSTALL_DATE:-unknown}"
    echo ""

    info "Checking for updates..."
    local latest
    latest=$(get_latest_version 2>/dev/null || echo "")

    if [[ -z "$latest" ]]; then
        warn "Could not check for updates"
    elif [[ "$latest" == "$TEMPLATE_VERSION" ]]; then
        echo -e "  ${GREEN}✓ You are running the latest version${NC}"
    else
        echo -e "  ${YELLOW}⚠ Update available: ${latest}${NC}"
        echo ""
        echo "  Run 'template-update update' to upgrade"
    fi
    echo ""
}

# Show changelog
cmd_changelog() {
    load_template_info

    local changelog_url="${TEMPLATE_REPO}/raw/main/templates/${TEMPLATE_NAME}/CHANGELOG.md"

    info "Fetching changelog..."
    curl -fsSL "$changelog_url" 2>/dev/null || warn "Changelog not available"
}

# Create backup before update
create_backup() {
    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="${BACKUP_DIR}/${backup_name}"

    mkdir -p "$backup_path"

    # Backup template info
    cp "$TEMPLATE_INFO_FILE" "$backup_path/"

    # Template-specific backups via update.sh
    if [[ -f "/usr/local/share/template/update.sh" ]]; then
        info "Running template-specific backup..."
        BACKUP_PATH="$backup_path" /usr/local/share/template/update.sh backup || true
    fi

    echo "$backup_name"
}

# Run update
cmd_update() {
    load_template_info

    local target_version="${1:-}"

    if [[ -z "$target_version" ]]; then
        target_version=$(get_latest_version 2>/dev/null || echo "")
        if [[ -z "$target_version" ]]; then
            die "Could not determine latest version"
        fi
    fi

    if [[ "$target_version" == "$TEMPLATE_VERSION" ]]; then
        info "Already running version $target_version"
        return 0
    fi

    info "Updating from $TEMPLATE_VERSION to $target_version"

    # Create backup
    info "Creating backup..."
    local backup_name
    backup_name=$(create_backup)
    info "Backup created: $backup_name"

    # Download and run update script
    local update_url="${TEMPLATE_REPO}/raw/main/templates/${TEMPLATE_NAME}/update.sh"

    info "Downloading update script..."
    local update_script
    update_script=$(mktemp)

    if ! curl -fsSL "$update_url" -o "$update_script" 2>/dev/null; then
        die "Failed to download update script"
    fi

    chmod +x "$update_script"

    info "Running update..."
    if TARGET_VERSION="$target_version" bash "$update_script" update; then
        # Update template info
        sed -i "s/^TEMPLATE_VERSION=.*/TEMPLATE_VERSION=\"${target_version}\"/" "$TEMPLATE_INFO_FILE"

        # Log update
        echo "$(date -Iseconds) | $TEMPLATE_VERSION -> $target_version | success" >> "$HISTORY_FILE"

        info "Update completed successfully!"
    else
        error "Update failed!"
        echo "$(date -Iseconds) | $TEMPLATE_VERSION -> $target_version | failed" >> "$HISTORY_FILE"
        warn "Run 'template-update rollback' to restore previous state"
        exit 1
    fi

    rm -f "$update_script"
}

# Rollback to previous version
cmd_rollback() {
    load_template_info

    if [[ ! -d "$BACKUP_DIR" ]]; then
        die "No backups found"
    fi

    local latest_backup
    latest_backup=$(ls -1t "$BACKUP_DIR" 2>/dev/null | head -1)

    if [[ -z "$latest_backup" ]]; then
        die "No backups found"
    fi

    local backup_path="${BACKUP_DIR}/${latest_backup}"

    info "Rolling back to backup: $latest_backup"

    # Restore template info
    if [[ -f "${backup_path}/template-info" ]]; then
        cp "${backup_path}/template-info" "$TEMPLATE_INFO_FILE"
    fi

    # Template-specific rollback
    if [[ -f "/usr/local/share/template/update.sh" ]]; then
        info "Running template-specific rollback..."
        BACKUP_PATH="$backup_path" /usr/local/share/template/update.sh rollback || true
    fi

    # Log rollback
    echo "$(date -Iseconds) | rollback to $latest_backup | success" >> "$HISTORY_FILE"

    info "Rollback completed!"
}

# Show update history
cmd_history() {
    if [[ ! -f "$HISTORY_FILE" ]]; then
        info "No update history found"
        return 0
    fi

    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Update History${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
    cat "$HISTORY_FILE"
    echo ""
}

# Show help
cmd_help() {
    echo "template-update v${VERSION}"
    echo ""
    echo "Usage: template-update <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status              Show current version and check for updates"
    echo "  update [version]    Update to latest or specific version"
    echo "  rollback            Restore last backup"
    echo "  changelog           Show changelog"
    echo "  history             Show update history"
    echo "  help                Show this help"
    echo ""
    echo "Examples:"
    echo "  template-update status"
    echo "  template-update update"
    echo "  template-update update 1.26.0-2"
    echo "  template-update rollback"
    echo ""
}

# === Main ===
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        status)    cmd_status "$@" ;;
        update)    cmd_update "$@" ;;
        rollback)  cmd_rollback "$@" ;;
        changelog) cmd_changelog "$@" ;;
        history)   cmd_history "$@" ;;
        help|--help|-h) cmd_help ;;
        *)
            error "Unknown command: $command"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
