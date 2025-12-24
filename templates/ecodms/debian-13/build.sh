#!/bin/bash
# templates/ecodms/build.sh
# Runs inside chroot during GitHub Actions build
# Following official ecoDMS installation guide for Debian 13
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# === Install dependencies ===
apt-get update
apt-get install -y --no-install-recommends \
	curl \
	ca-certificates \
	gnupg \
	postgresql \
	postgresql-client

# === Create ecodms user/group with fixed IDs (for shared volumes) ===
# Must be created BEFORE installing ecodmsserver to use our fixed IDs
if [[ -n "${TEMPLATE_GID:-}" ]]; then
	groupadd -g "$TEMPLATE_GID" ecodms
fi
if [[ -n "${TEMPLATE_UID:-}" ]]; then
	useradd -r -u "$TEMPLATE_UID" -g ecodms -s /usr/sbin/nologin -d /opt/ecodms ecodms
fi

# === Start PostgreSQL (required for ecoDMS installation) ===
# In chroot environment, services don't start automatically
# Find PostgreSQL data directory and start manually
PG_DATA=$(find /var/lib/postgresql -name "main" -type d 2>/dev/null | head -1)
if [[ -z "$PG_DATA" ]]; then
	echo "ERROR: PostgreSQL data directory not found"
	exit 1
fi

# Ensure socket directory exists
mkdir -p /var/run/postgresql
chown postgres:postgres /var/run/postgresql

# Start PostgreSQL as postgres user
echo "Starting PostgreSQL..."
su - postgres -c "pg_ctl start -D '$PG_DATA' -l /var/log/postgresql/startup.log -w -t 60" || {
	echo "pg_ctl start failed, trying pg_ctlcluster..."
	pg_ctlcluster "$(pg_lsclusters -h | awk 'NR==1{print $1}')" main start || true
}

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
for i in {1..30}; do
	if su - postgres -c "pg_isready" &>/dev/null; then
		echo "PostgreSQL is ready"
		break
	fi
	echo "Waiting... ($i/30)"
	sleep 1
done

# Verify PostgreSQL is running
if ! su - postgres -c "pg_isready" &>/dev/null; then
	echo "ERROR: PostgreSQL failed to start"
	cat /var/log/postgresql/startup.log 2>/dev/null || true
	exit 1
fi

# === Add ecoDMS repository (DEB822 format for Debian 13) ===
mkdir -p /etc/apt/keyrings

curl -fsSL http://www.ecodms.de/gpg/ecodms.key | gpg --dearmor -o /etc/apt/keyrings/ecodms.gpg
chmod 644 /etc/apt/keyrings/ecodms.gpg

cat >/etc/apt/sources.list.d/ecodms.sources <<'EOF'
Types: deb
URIs: http://www.ecodms.de/ecodms_250264/trixie
Suites: /
Signed-By: /etc/apt/keyrings/ecodms.gpg
EOF

apt-get update

# === Pre-configure ecoDMS to avoid interactive prompts ===
echo "ecodmsserver ecodmsserver/language select English" | debconf-set-selections
echo "ecodmsserver ecodmsserver/license boolean true" | debconf-set-selections

# === Install ecoDMS Server ===
echo "Installing ecoDMS Server..."
apt-get install -y ecodmsserver

# === Stop PostgreSQL (will start on container boot) ===
echo "Stopping PostgreSQL..."
su - postgres -c "pg_ctl stop -D '$PG_DATA' -m fast" || true

# === Create data directory with correct permissions ===
mkdir -p /srv/data
if [[ -n "${TEMPLATE_GID:-}" ]]; then
	chgrp -R "$TEMPLATE_GID" /srv/data
	chmod -R 2775 /srv/data
fi

# === Template info ===
cat >/etc/template-info <<EOF
TEMPLATE_NAME="${TEMPLATE_NAME}"
TEMPLATE_REPO="${TEMPLATE_REPO}"
TEMPLATE_VERSION="${TEMPLATE_VERSION}"
INSTALL_DATE="__DATE__"
EOF

# === Install template-update tool ===
repo_raw_url="${TEMPLATE_REPO//github.com/raw.githubusercontent.com}/main"
curl -fsSL "${repo_raw_url}/scripts/template-update.sh" \
	-o /usr/local/bin/template-update
chmod +x /usr/local/bin/template-update

# === Enable services ===
systemctl enable postgresql
systemctl enable ecodms

# === Cleanup ===
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
