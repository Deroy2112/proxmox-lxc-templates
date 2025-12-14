<p align="center">
  <h1 align="center">Proxmox LXC Templates</h1>
  <p align="center">
    Ready-to-use LXC container templates with checksum verification
  </p>
</p>

<p align="center">
  <a href="https://github.com/Deroy2112/proxmox-lxc-templates/actions/workflows/build-template.yml">
    <img src="https://github.com/Deroy2112/proxmox-lxc-templates/actions/workflows/build-template.yml/badge.svg" alt="Build Status">
  </a>
  <a href="https://github.com/Deroy2112/proxmox-lxc-templates/releases">
    <img src="https://img.shields.io/github/v/release/Deroy2112/proxmox-lxc-templates?label=latest" alt="Latest Release">
  </a>
  <a href="https://github.com/Deroy2112/proxmox-lxc-templates/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/Deroy2112/proxmox-lxc-templates" alt="License">
  </a>
</p>

---

## Installation

### Option 1: Web UI

1. Go to **Storage** → **local** → **CT Templates**
2. Click **Download from URL**
3. Paste URL and SHA-512 checksum from our [website](https://deroy2112.github.io/proxmox-lxc-templates/)

### Option 2: CLI

Run on your Proxmox node as root:

```bash
pvesh create /nodes/$(hostname)/storage/local/download-url \
  --content vztmpl \
  --filename deroy2112-debian-13-nginx_1.26.0-1_amd64.tar.zst \
  --url https://github.com/Deroy2112/proxmox-lxc-templates/releases/download/v1.26.0-1-nginx/deroy2112-debian-13-nginx_1.26.0-1_amd64.tar.zst \
  --checksum <SHA512> \
  --checksum-algorithm sha512
```

Get the full command with checksum from our [website](https://deroy2112.github.io/proxmox-lxc-templates/).

---

## Available Templates

| Template | Description | Base OS |
|----------|-------------|---------|
| **nginx** | Nginx Webserver | Debian 13 |

---

## Features

| | Feature |
|---|---------|
| **Verified** | All downloads are SHA-512 verified |
| **Reproducible** | Built with GitHub Actions using debootstrap |
| **Updateable** | Update running containers without rebuilding |
| **Rollback** | Automatic backups before every update |

---

## Update Running Containers

Every template includes a built-in update tool:

```bash
template-update status      # Check for updates
template-update update      # Apply update
template-update rollback    # Restore previous version
```

---

## Links

- **Website:** https://deroy2112.github.io/proxmox-lxc-templates/
- **Releases:** https://github.com/Deroy2112/proxmox-lxc-templates/releases

---

## License

[MIT](LICENSE)
