# proxmox-lxc-templates

Self-updating LXC template repository for Proxmox VE with native UI integration.

## Features

- **Native Proxmox UI Integration** - Templates appear alongside official Proxmox templates
- **One-Liner Installation** - Single command with checksum verification
- **Automatic Updates** - Daily cronjob keeps templates current
- **In-Container Updates** - Update running containers without rebuilding
- **Rollback Support** - Automatic backups before updates
- **Reproducible Builds** - All templates built via GitHub Actions with debootstrap

## Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Deroy2112/proxmox-lxc-templates/main/install.sh)
```

### What happens

1. Verifies checksum of the installer
2. Checks for Proxmox VE installation
3. Downloads and verifies template index
4. Installs to `/var/lib/pve-manager/apl-info/`
5. Sets up daily update cronjob

### After installation

Open Proxmox UI → Datacenter → Storage → local → CT Templates

Your templates appear alongside official Proxmox templates.

## Available Templates

| Template | Description | Base OS |
|----------|-------------|---------|
| nginx | Nginx webserver | Debian 13 |

## In-Container Updates

Each template includes an update tool:

```bash
# Check for updates
template-update status

# Apply update
template-update update

# Rollback to previous version
template-update rollback

# Show changelog
template-update changelog
```

## Uninstallation

```bash
# Remove cronjob
rm /etc/cron.daily/proxmox-lxc-templates-update

# Remove template index
rm /var/lib/pve-manager/apl-info/proxmox-lxc-templates.dat
```

## Building Templates

Templates are automatically built via GitHub Actions when changes are pushed to `templates/`.

### Template Structure

```
templates/
└── nginx/
    ├── config.yml      # Metadata and version
    ├── build.sh        # Build script (runs in chroot)
    ├── update.sh       # In-container update script
    ├── CHANGELOG.md    # Version history
    └── files/          # Additional config files
```

### Manual Build Trigger

Go to Actions → Build LXC Template → Run workflow

## License

MIT License - See [LICENSE](LICENSE)
