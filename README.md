<p align="center">
  <h1 align="center">Proxmox LXC Templates</h1>
  <p align="center">
    Self-updating LXC template repository with native Proxmox UI integration
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

Run this command on your Proxmox server as root:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Deroy2112/proxmox-lxc-templates/main/install.sh)
```

Templates will appear in **Datacenter → Storage → local → CT Templates**.

---

## Features

| | Feature |
|---|---------|
| **Native UI** | Templates appear alongside official Proxmox templates |
| **Auto Updates** | Daily cronjob keeps your template index current |
| **Verified** | All downloads are SHA256 verified |
| **Updateable** | Update running containers without rebuilding |
| **Rollback** | Automatic backups before every update |

---

## Available Templates

| Template | Description | Base OS |
|----------|-------------|---------|
| **nginx** | Nginx Webserver | Debian 13 |

---

## Update Running Containers

Every template includes a built-in update tool:

```bash
template-update status      # Check for updates
template-update update      # Apply update
template-update rollback    # Restore previous version
```

---

## Uninstall

```bash
rm /etc/cron.daily/proxmox-lxc-templates-update
rm /var/lib/pve-manager/apl-info/proxmox-lxc-templates.dat
```

---

## Links

- **Website:** https://deroy2112.github.io/proxmox-lxc-templates/
- **Releases:** https://github.com/Deroy2112/proxmox-lxc-templates/releases

---

## License

[MIT](LICENSE)
