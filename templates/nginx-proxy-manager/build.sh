#!/bin/bash
# templates/nginx-proxy-manager/build.sh
# Runs inside systemd-nspawn chroot during GitHub Actions build
# Based on community-scripts/ProxmoxVE bare-metal installation
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

readonly NPM_VERSION="2.13.5"
readonly APP_DIR="/app"
readonly DATA_DIR="/data"

# === Install base dependencies ===
apt-get update
apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    git \
    build-essential \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    python3-cffi \
    openssl \
    apache2-utils \
    logrotate

# === Setup Certbot in virtualenv ===
python3 -m venv /opt/certbot
/opt/certbot/bin/pip install --upgrade pip
/opt/certbot/bin/pip install certbot certbot-dns-cloudflare
ln -sf /opt/certbot/bin/certbot /usr/bin/certbot

# === Add Node.js repository (Node.js 22 LTS) ===
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
chmod 644 /etc/apt/keyrings/nodesource.gpg

cat > /etc/apt/sources.list.d/nodesource.sources <<'EOF'
Types: deb
URIs: https://deb.nodesource.com/node_22.x
Suites: nodistro
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/nodesource.gpg
EOF

# === Add OpenResty repository (using bookworm - compatible with trixie) ===
curl -fsSL https://openresty.org/package/pubkey.gpg \
    | gpg --dearmor -o /etc/apt/keyrings/openresty.gpg
chmod 644 /etc/apt/keyrings/openresty.gpg

cat > /etc/apt/sources.list.d/openresty.sources <<'EOF'
Types: deb
URIs: https://openresty.org/package/debian
Suites: bookworm
Components: openresty
Architectures: amd64
Signed-By: /etc/apt/keyrings/openresty.gpg
EOF

# === Install Node.js and OpenResty ===
apt-get update
apt-get install -y --no-install-recommends \
    nodejs \
    openresty

# === Create directory structure ===
mkdir -p "$APP_DIR"/{frontend,backend}
mkdir -p "$DATA_DIR"/{nginx,logs,letsencrypt,access,custom_ssl}
mkdir -p "$DATA_DIR/nginx"/{proxy_host,redirection_host,dead_host,stream,temp}
mkdir -p /var/cache/nginx/proxy_temp
mkdir -p /run/nginx

# === Create symbolic links for binaries ===
ln -sf /usr/bin/python3 /usr/bin/python
ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/sbin/nginx

# === Download NPM source ===
curl -fsSL "https://github.com/NginxProxyManager/nginx-proxy-manager/archive/refs/tags/v${NPM_VERSION}.tar.gz" \
    -o /tmp/npm.tar.gz
tar -xzf /tmp/npm.tar.gz -C /tmp
cd "/tmp/nginx-proxy-manager-${NPM_VERSION}"

# === Copy nginx configuration to OpenResty directory ===
cp -r docker/rootfs/etc/nginx/* /usr/local/openresty/nginx/conf/
rm -f /usr/local/openresty/nginx/conf/conf.d/default.conf
ln -sf /usr/local/openresty/nginx/conf /etc/nginx

# === Copy backend ===
cp -r backend/* "$APP_DIR/backend/"

# === Build Frontend ===
cd "/tmp/nginx-proxy-manager-${NPM_VERSION}/frontend"

# Replace node-sass with sass (compatibility fix)
sed -i 's/"node-sass"/"sass"/g' package.json
npm install
npm run build
cp -r dist/* "$APP_DIR/frontend/"

# === Build Backend ===
cd "$APP_DIR/backend"
npm install

# === Create backend config ===
mkdir -p "$APP_DIR/config"
cat > "$APP_DIR/config/production.json" <<'EOF'
{
  "database": {
    "engine": "knex-native",
    "knex": {
      "client": "sqlite3",
      "connection": {
        "filename": "/data/database.sqlite"
      },
      "useNullAsDefault": true
    }
  }
}
EOF

# === Generate dummy SSL certificates ===
if [[ ! -f /data/nginx/dummycert.pem ]] || [[ ! -f /data/nginx/dummykey.pem ]]; then
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
        -subj "/O=Nginx Proxy Manager/OU=Dummy Certificate/CN=localhost" \
        -keyout /data/nginx/dummykey.pem \
        -out /data/nginx/dummycert.pem
fi

# === Patch nginx config for non-Docker environment ===
sed -i 's|include /etc/nginx/conf.d/include/force-ssl.conf;||g' /etc/nginx/conf.d/default.conf
sed -i 's|include /etc/nginx/conf.d/include/letsencrypt-acme-challenge.conf;||g' /etc/nginx/conf.d/default.conf

# === Create systemd service ===
cat > /lib/systemd/system/npm.service <<'EOF'
[Unit]
Description=Nginx Proxy Manager
After=network.target openresty.service
Wants=openresty.service

[Service]
Type=simple
Environment=NODE_ENV=production
Environment=NODE_OPTIONS="--max_old_space_size=250"
WorkingDirectory=/app/backend
ExecStart=/usr/bin/node index.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# === Create logrotate config ===
cat > /etc/logrotate.d/npm <<'EOF'
/data/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        [ -f /run/nginx/nginx.pid ] && kill -USR1 $(cat /run/nginx/nginx.pid)
    endscript
}
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

# === Enable services ===
systemctl enable openresty
systemctl enable npm

# === Cleanup ===
rm -rf /tmp/npm.tar.gz "/tmp/nginx-proxy-manager-${NPM_VERSION}"
npm cache clean --force
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# === Print info ===
cat <<'INFO'
=============================================
Nginx Proxy Manager installed successfully
=============================================
Admin UI:     http://<container-ip>:81
HTTP Port:    80
HTTPS Port:   443

Default credentials:
  Email:    admin@example.com
  Password: changeme
=============================================
INFO
