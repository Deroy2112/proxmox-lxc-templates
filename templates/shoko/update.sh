#!/bin/bash
# templates/shoko/update.sh
# In-container update script for shoko template
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

readonly COMMAND="${1:-}"
readonly BACKUP_PATH="${BACKUP_PATH:-/var/backups/template-update/current}"
readonly SHOKO_DIR="/opt/shoko"

# === Functions ===
do_backup() {
    mkdir -p "$BACKUP_PATH"

    # Backup Shoko installation
    if [[ -d "$SHOKO_DIR" ]]; then
        cp -r "$SHOKO_DIR" "$BACKUP_PATH/"
    fi

    # Backup Shoko data
    if [[ -d /home/shoko/.shoko ]]; then
        mkdir -p "$BACKUP_PATH/.shoko"
        cp -r /home/shoko/.shoko "$BACKUP_PATH/"
    fi

    echo "Backup completed"
}

do_update() {
    # Update system packages
    apt-get update
    apt-get upgrade -y

    # Restart Shoko
    systemctl restart shoko

    echo "Update completed"
}

do_rollback() {
    # Stop Shoko before restore
    systemctl stop shoko

    # Restore Shoko installation
    if [[ -d "$BACKUP_PATH/shoko" ]]; then
        rm -rf "$SHOKO_DIR"
        cp -r "$BACKUP_PATH/shoko" /opt/
    fi

    # Restore Shoko data
    if [[ -d "$BACKUP_PATH/.shoko" ]]; then
        rm -rf /home/shoko/.shoko
        cp -r "$BACKUP_PATH/.shoko" /home/shoko/
    fi

    # Restart Shoko
    systemctl start shoko

    echo "Rollback completed"
}

# === Main ===
case "$COMMAND" in
    backup)   do_backup ;;
    update)   do_update ;;
    rollback) do_rollback ;;
    *)
        echo "Usage: $0 {backup|update|rollback}"
        exit 1
        ;;
esac
