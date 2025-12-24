#!/bin/bash
# templates/ecodms/update.sh
# In-container update script for ecoDMS template
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

readonly COMMAND="${1:-}"
readonly BACKUP_PATH="${BACKUP_PATH:-/var/backups/template-update/current}"

# === Functions ===
do_backup() {
	mkdir -p "$BACKUP_PATH"

	# Stop services before backup
	systemctl stop ecodms || true

	# Backup ecoDMS data directory
	if [[ -d /srv/data ]]; then
		cp -r /srv/data "$BACKUP_PATH/"
	fi

	# Backup PostgreSQL database
	if command -v pg_dump &>/dev/null; then
		if ! su - postgres -c "pg_dumpall" >"$BACKUP_PATH/postgresql_dump.sql" 2>&1; then
			echo "WARNING: PostgreSQL backup may have failed"
		fi
	fi

	# Restart services
	systemctl start ecodms || true

	echo "Backup completed"
}

do_update() {
	# Update package lists
	apt-get update

	# Upgrade all packages (PostgreSQL + ecoDMS)
	apt-get upgrade -y

	# Restart services
	systemctl restart ecodms

	echo "Update completed"
}

do_rollback() {
	# Stop services before restore
	systemctl stop ecodms || true

	# Restore ecoDMS data directory
	if [[ -d "$BACKUP_PATH/data" ]]; then
		rm -rf /srv/data
		cp -r "$BACKUP_PATH/data" /srv/
	fi

	# Restore PostgreSQL database
	if [[ -f "$BACKUP_PATH/postgresql_dump.sql" ]]; then
		su - postgres -c "psql -f '$BACKUP_PATH/postgresql_dump.sql'" 2>/dev/null || true
	fi

	# Restart services
	systemctl start ecodms

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
