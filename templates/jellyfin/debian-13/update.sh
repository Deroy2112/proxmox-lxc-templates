#!/bin/bash
# templates/jellyfin/update.sh
# In-container update script for jellyfin template
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

readonly COMMAND="${1:-}"
readonly BACKUP_PATH="${BACKUP_PATH:-/var/backups/template-update/current}"

# === Functions ===
do_backup() {
	mkdir -p "$BACKUP_PATH"

	# Backup Jellyfin config
	if [[ -d /etc/jellyfin ]]; then
		cp -r /etc/jellyfin "$BACKUP_PATH/"
	fi

	# Backup Jellyfin data (metadata, not media files)
	if [[ -d /var/lib/jellyfin ]]; then
		cp -r /var/lib/jellyfin "$BACKUP_PATH/"
	fi

	echo "Backup completed"
}

do_update() {
	# Update system packages
	apt-get update
	apt-get upgrade -y

	# Restart Jellyfin
	systemctl restart jellyfin

	echo "Update completed"
}

do_rollback() {
	# Stop Jellyfin before restore
	systemctl stop jellyfin

	# Restore Jellyfin config
	if [[ -d "$BACKUP_PATH/jellyfin" ]]; then
		rm -rf /etc/jellyfin
		cp -r "$BACKUP_PATH/jellyfin" /etc/
	fi

	# Restore Jellyfin data
	if [[ -d "$BACKUP_PATH/lib/jellyfin" ]]; then
		rm -rf /var/lib/jellyfin
		cp -r "$BACKUP_PATH/lib/jellyfin" /var/lib/
	fi

	# Restart Jellyfin
	systemctl start jellyfin

	echo "Rollback completed"
}

# === Main ===
case "$COMMAND" in
backup) do_backup ;;
update) do_update ;;
rollback) do_rollback ;;
*)
	echo "Usage: $0 {backup|update|rollback}"
	exit 1
	;;
esac
