#!/bin/bash
# templates/ecodms/build.sh
# Runs inside systemd-nspawn chroot during GitHub Actions build
# Following official ecoDMS installation guide for Debian 13
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# === Install dependencies ===
apt-get update
apt-get install -y --no-install-recommends \
	curl \
	ca-certificates \
	gnupg

# === Create ecodms group with fixed GID (for shared volumes) ===
if [[ -n "${TEMPLATE_GID:-}" ]]; then
	groupadd -g "$TEMPLATE_GID" ecodms
fi

# === Add ecoDMS repository (DEB822 format for Debian 13) ===
# Official guide: https://www.ecodms.de/en/ecodms-archiv/systemvoraussetzungen
# Note: ecoDMS only provides HTTP repository
mkdir -p /etc/apt/keyrings

# Download and convert GPG key (official: wget -qO /etc/apt/trusted.gpg.d/ecodms.asc)
curl -fsSL http://www.ecodms.de/gpg/ecodms.key | gpg --dearmor -o /etc/apt/keyrings/ecodms.gpg
chmod 644 /etc/apt/keyrings/ecodms.gpg

# Official source: deb http://www.ecodms.de/ecodms_250264/trixie /
cat >/etc/apt/sources.list.d/ecodms.sources <<'EOF'
Types: deb
URIs: http://www.ecodms.de/ecodms_250264/trixie
Suites: /
Signed-By: /etc/apt/keyrings/ecodms.gpg
EOF

# === Update package lists ===
apt-get update

# === Pre-configure ecoDMS to avoid interactive prompts ===
# Accept license and set language to English
echo "ecodmsserver ecodmsserver/language select English" | debconf-set-selections
echo "ecodmsserver ecodmsserver/license boolean true" | debconf-set-selections

# === Install ecoDMS Server ===
# Official guide: sudo apt-get install ecodmsserver
# This installs PostgreSQL as dependency and creates the ecodms database
apt-get install -y ecodmsserver

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
