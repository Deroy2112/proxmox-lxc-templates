#!/bin/bash
# templates/jdownloader/update.sh
# In-container update script for jdownloader template
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

readonly COMMAND="${1:-}"
readonly BACKUP_PATH="${BACKUP_PATH:-/var/backups/template-update/current}"
readonly JD_DIR="/opt/jdownloader"

# === Functions ===
do_backup() {
    mkdir -p "$BACKUP_PATH"

    # Backup JDownloader config
    if [[ -d "$JD_DIR/cfg" ]]; then
        cp -r "$JD_DIR/cfg" "$BACKUP_PATH/"
    fi

    echo "Backup completed"
}

do_update() {
    # Update system packages
    apt-get update
    apt-get upgrade -y

    # Restart JDownloader (it auto-updates itself on restart)
    systemctl restart jdownloader

    echo "Update completed"
}

do_rollback() {
    # Stop JDownloader before restore
    systemctl stop jdownloader

    # Restore JDownloader config
    if [[ -d "$BACKUP_PATH/cfg" ]]; then
        rm -rf "$JD_DIR/cfg"
        cp -r "$BACKUP_PATH/cfg" "$JD_DIR/"
        chown -R jdownloader:jdownloader "$JD_DIR/cfg"
    fi

    # Restart JDownloader
    systemctl start jdownloader

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
