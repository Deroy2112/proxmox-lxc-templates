#!/bin/bash
# templates/jellyfin/build.sh
# Runs inside systemd-nspawn chroot during GitHub Actions build
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# === Install dependencies ===
apt-get update
apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg

# === Add Jellyfin repository ===
curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key \
    | gpg --dearmor -o /usr/share/keyrings/jellyfin-archive-keyring.gpg

cat > /etc/apt/sources.list.d/jellyfin.sources <<'EOF'
Types: deb
URIs: https://repo.jellyfin.org/debian
Suites: bookworm
Components: main
Signed-By: /usr/share/keyrings/jellyfin-archive-keyring.gpg
EOF

# === Install Jellyfin ===
apt-get update
apt-get install -y --no-install-recommends \
    jellyfin

# === Create media directories ===
mkdir -p /media/{movies,tvshows,music}
chown -R jellyfin:jellyfin /media

# === Template info ===
cat > /etc/template-info <<EOF
TEMPLATE_NAME="${TEMPLATE_NAME}"
TEMPLATE_REPO="${TEMPLATE_REPO}"
TEMPLATE_VERSION="${TEMPLATE_VERSION}"
INSTALL_DATE="__DATE__"
EOF

# === Install template-update tool ===
repo_raw_url=$(echo "${TEMPLATE_REPO}" | sed 's|github.com|raw.githubusercontent.com|')/main
curl -fsSL "${repo_raw_url}/scripts/template-update.sh" \
    -o /usr/local/bin/template-update
chmod +x /usr/local/bin/template-update

# === Enable services ===
systemctl enable jellyfin

# === Cleanup ===
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
