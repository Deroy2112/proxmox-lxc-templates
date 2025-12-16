#!/bin/bash
# templates/jdownloader/build.sh
# Runs inside systemd-nspawn chroot during GitHub Actions build
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

readonly JD_USER="jdownloader"
readonly JD_DIR="/opt/jdownloader"
readonly DOWNLOAD_DIR="/downloads"

# === Install dependencies ===
# Note: Full JRE required, NOT headless (official JDownloader requirement)
apt-get update
apt-get install -y --no-install-recommends \
    openjdk-17-jre \
    curl \
    ca-certificates

# === Create jdownloader user/group with fixed IDs (for shared volumes) ===
if [[ -n "${TEMPLATE_GID:-}" ]]; then
  groupadd -g "$TEMPLATE_GID" "$JD_USER"
fi
if [[ -n "${TEMPLATE_UID:-}" ]]; then
  useradd -r -u "$TEMPLATE_UID" -g "${TEMPLATE_GID:-$JD_USER}" \
    -s /usr/sbin/nologin -d "$JD_DIR" "$JD_USER"
else
  useradd -r -g "$JD_USER" -s /usr/sbin/nologin -d "$JD_DIR" "$JD_USER"
fi

# === Create directories ===
mkdir -p "$JD_DIR" "$JD_DIR/cfg" "$DOWNLOAD_DIR"

# === Download JDownloader.jar ===
curl -fsSL "http://installer.jdownloader.org/JDownloader.jar" \
    -o "$JD_DIR/JDownloader.jar"

# === Set ownership ===
chown -R "$JD_USER:$JD_USER" "$JD_DIR" "$DOWNLOAD_DIR"

# === Create systemd service ===
cat > /etc/systemd/system/jdownloader.service <<EOF
[Unit]
Description=JDownloader 2 Download Manager
After=network.target

[Service]
Type=simple
User=$JD_USER
Group=$JD_USER
WorkingDirectory=$JD_DIR
Environment=JD_HOME=$JD_DIR
ExecStart=/usr/bin/java -Djava.awt.headless=true -jar $JD_DIR/JDownloader.jar
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# === Template info ===
cat > /etc/template-info <<EOF
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

# === Enable service ===
systemctl enable jdownloader

# === Cleanup ===
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
