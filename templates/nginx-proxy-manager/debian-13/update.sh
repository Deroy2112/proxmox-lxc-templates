#!/bin/bash
# templates/nginx-proxy-manager/update.sh
# In-container update script for Nginx Proxy Manager template
# Based on community-scripts/ProxmoxVE bare-metal installation
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

readonly COMMAND="${1:-}"
readonly BACKUP_PATH="${BACKUP_PATH:-/var/backups/template-update/current}"
readonly APP_DIR="/app"
readonly DATA_DIR="/data"

# === Functions ===
do_backup() {
	mkdir -p "$BACKUP_PATH"

	# Backup NPM data directory (database, configs, certificates)
	if [[ -d "$DATA_DIR" ]]; then
		cp -r "$DATA_DIR" "$BACKUP_PATH/"
	fi

	# Backup nginx configuration
	if [[ -d /etc/nginx ]]; then
		cp -rL /etc/nginx "$BACKUP_PATH/nginx-conf"
	fi

	# Backup backend config
	if [[ -d "$APP_DIR/config" ]]; then
		cp -r "$APP_DIR/config" "$BACKUP_PATH/app-config"
	fi

	echo "Backup completed to $BACKUP_PATH"
}

do_update() {
	# Stop services
	systemctl stop npm || true
	systemctl stop openresty || true

	# Update system packages
	apt-get update
	apt-get upgrade -y

	# Update certbot in virtualenv
	/opt/certbot/bin/pip install --upgrade certbot certbot-dns-cloudflare

	# Restart services
	systemctl start openresty
	systemctl start npm

	echo "Update completed"
}

do_rollback() {
	# Stop services
	systemctl stop npm || true
	systemctl stop openresty || true

	# Restore NPM data
	if [[ -d "$BACKUP_PATH/data" ]]; then
		rm -rf "$DATA_DIR"
		cp -r "$BACKUP_PATH/data" "$DATA_DIR"
	fi

	# Restore nginx configuration
	if [[ -d "$BACKUP_PATH/nginx-conf" ]]; then
		rm -rf /etc/nginx
		cp -r "$BACKUP_PATH/nginx-conf" /etc/nginx
	fi

	# Restore app config
	if [[ -d "$BACKUP_PATH/app-config" ]]; then
		rm -rf "$APP_DIR/config"
		cp -r "$BACKUP_PATH/app-config" "$APP_DIR/config"
	fi

	# Restart services
	systemctl start openresty
	systemctl start npm

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
