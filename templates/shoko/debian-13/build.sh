#!/bin/bash
# templates/shoko/build.sh
# Runs inside systemd-nspawn chroot during GitHub Actions build
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

readonly SHOKO_VERSION="5.1.0"
readonly SHOKO_USER="shoko"
readonly SHOKO_DIR="/opt/shoko"

# === Install dependencies ===
apt-get update
apt-get install -y --no-install-recommends \
	curl \
	ca-certificates \
	gnupg \
	unzip \
	mediainfo \
	librhash-dev

# === Add Microsoft .NET repository (using bookworm - compatible with trixie) ===
mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
	gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
chmod 644 /etc/apt/keyrings/microsoft.gpg

cat >/etc/apt/sources.list.d/microsoft.sources <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/debian/12/prod
Suites: bookworm
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/microsoft.gpg
EOF

# === Install ASP.NET Core 8.0 Runtime (includes Microsoft.AspNetCore.App framework) ===
apt-get update
apt-get install -y --no-install-recommends \
	aspnetcore-runtime-8.0

# === Create shoko user/group with fixed IDs (for shared volumes) ===
if [[ -n "${TEMPLATE_GID:-}" ]]; then
	groupadd -g "$TEMPLATE_GID" "$SHOKO_USER"
fi
if [[ -n "${TEMPLATE_UID:-}" ]]; then
	useradd -r -u "$TEMPLATE_UID" -g "${TEMPLATE_GID:-$SHOKO_USER}" \
		-s /usr/sbin/nologin -d "$SHOKO_DIR" "$SHOKO_USER"
else
	useradd -r -s /usr/sbin/nologin -d "$SHOKO_DIR" "$SHOKO_USER"
fi

# === Download and install Shoko Server ===
mkdir -p "$SHOKO_DIR"
curl -fsSL "https://github.com/ShokoAnime/ShokoServer/releases/download/v${SHOKO_VERSION}/Shoko.CLI_Framework_any-x64.zip" \
	-o /tmp/shoko.zip
unzip -q /tmp/shoko.zip -d /tmp/shoko-extract
mv /tmp/shoko-extract/net8.0/linux-x64/* "$SHOKO_DIR/"
chmod +x "$SHOKO_DIR/Shoko.CLI"
chown -R "$SHOKO_USER:$SHOKO_USER" "$SHOKO_DIR"
rm -rf /tmp/shoko.zip /tmp/shoko-extract

# === Create media directories ===
mkdir -p /media/anime
chown -R "$SHOKO_USER:$SHOKO_USER" /media

# === Create systemd service ===
cat >/etc/systemd/system/shoko.service <<EOF
[Unit]
Description=Shoko Anime Server
After=network.target

[Service]
Type=simple
User=$SHOKO_USER
Group=$SHOKO_USER
WorkingDirectory=$SHOKO_DIR
ExecStart=$SHOKO_DIR/Shoko.CLI
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# === Template info ===
cat >/etc/template-info <<EOF
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
systemctl enable shoko

# === Cleanup ===
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
