#!/bin/bash
# templates/vaultwarden/build.sh
# Runs inside systemd-nspawn chroot during GitHub Actions build
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

readonly VAULTWARDEN_VERSION="${TEMPLATE_VERSION%-*}"
readonly BINARY_REPO="https://github.com/czyt/vaultwarden-binary/releases/download"
readonly DOWNLOAD_URL="${BINARY_REPO}/${VAULTWARDEN_VERSION}-extracted/vaultwarden-linux-amd64-extracted.zip"

# === Install dependencies ===
apt-get update
apt-get install -y --no-install-recommends \
	ca-certificates \
	curl \
	unzip \
	libssl3t64 \
	libsqlite3-0

# === Create shared group and vaultwarden user ===
if [[ -n "${TEMPLATE_GID:-}" ]]; then
	groupadd -g "$TEMPLATE_GID" shared
fi

if [[ -n "${TEMPLATE_UID:-}" ]]; then
	useradd -r -u "$TEMPLATE_UID" -g shared -d /var/lib/vaultwarden -s /usr/sbin/nologin vaultwarden
else
	useradd -r -g shared -d /var/lib/vaultwarden -s /usr/sbin/nologin vaultwarden
fi

# === Download and extract Vaultwarden ===
cd /var/tmp
curl -fsSL -o vaultwarden.zip "$DOWNLOAD_URL"
unzip -q vaultwarden.zip

# Install binary
install -m 755 vaultwarden /usr/local/bin/vaultwarden

# Install web vault
mkdir -p /usr/share/vaultwarden
cp -r web-vault /usr/share/vaultwarden/

# Cleanup download
rm -rf vaultwarden.zip vaultwarden web-vault

# === Create directories ===
mkdir -p /var/lib/vaultwarden/{data,attachments,sends,icon_cache}
mkdir -p /etc/vaultwarden

chown -R vaultwarden:shared /var/lib/vaultwarden
chmod 750 /var/lib/vaultwarden

# === Create configuration ===
cat > /etc/vaultwarden/vaultwarden.env << 'EOF'
## Vaultwarden Configuration
## Documentation: https://github.com/dani-garcia/vaultwarden/wiki

# Server settings
ROCKET_ADDRESS=0.0.0.0
ROCKET_PORT=8080

# Data directory
DATA_FOLDER=/var/lib/vaultwarden/data
ATTACHMENTS_FOLDER=/var/lib/vaultwarden/attachments
SENDS_FOLDER=/var/lib/vaultwarden/sends
ICON_CACHE_FOLDER=/var/lib/vaultwarden/icon_cache

# Web vault location
WEB_VAULT_FOLDER=/usr/share/vaultwarden/web-vault

# WebSocket notifications (optional, for live sync)
WEBSOCKET_ENABLED=true
WEBSOCKET_ADDRESS=0.0.0.0
WEBSOCKET_PORT=3012

# Logging
LOG_LEVEL=info
EXTENDED_LOGGING=true

# Registration (enable temporarily for initial setup, then disable)
SIGNUPS_ALLOWED=false

# Admin panel (generate token: openssl rand -base64 48)
# ADMIN_TOKEN=

# SMTP for email (optional)
# SMTP_HOST=smtp.example.com
# SMTP_PORT=587
# SMTP_SECURITY=starttls
# SMTP_USERNAME=
# SMTP_PASSWORD=
# SMTP_FROM=vaultwarden@example.com

# Domain (required for proper URL generation with reverse proxy)
# DOMAIN=https://vault.example.com
EOF

chown root:vaultwarden /etc/vaultwarden/vaultwarden.env
chmod 640 /etc/vaultwarden/vaultwarden.env

# === Create systemd service ===
cat > /etc/systemd/system/vaultwarden.service << 'EOF'
[Unit]
Description=Vaultwarden Password Manager
Documentation=https://github.com/dani-garcia/vaultwarden
After=network.target

[Service]
Type=exec
User=vaultwarden
Group=shared
EnvironmentFile=/etc/vaultwarden/vaultwarden.env
ExecStart=/usr/local/bin/vaultwarden
Restart=on-failure
RestartSec=5

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/vaultwarden
CapabilityBoundingSet=
AmbientCapabilities=
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF

# === Template info ===
cat > /etc/template-info << EOF
TEMPLATE_NAME="${TEMPLATE_NAME}"
TEMPLATE_REPO="${TEMPLATE_REPO}"
TEMPLATE_VERSION="${TEMPLATE_VERSION}"
INSTALL_DATE="__DATE__"
EOF

# === Install template-update tool ===
repo_raw_url="${TEMPLATE_REPO/github.com/raw.githubusercontent.com}/main"
curl -fsSL "${repo_raw_url}/scripts/template-update.sh" \
	-o /usr/local/bin/template-update
chmod +x /usr/local/bin/template-update

# === Enable services ===
systemctl enable vaultwarden

# === Cleanup ===
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
