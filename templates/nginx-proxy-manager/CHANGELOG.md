# Changelog

All notable changes to the nginx-proxy-manager template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.13.5-1] - 2025-12-14

### Added

- Initial release (bare-metal installation based on community-scripts/ProxmoxVE)
- Nginx Proxy Manager 2.13.5 with web-based management UI
- OpenResty (nginx with Lua) for reverse proxy
- Node.js 22 LTS with Yarn package manager
- SQLite database for configuration storage
- Certbot in Python virtualenv with Cloudflare DNS plugin
- Let's Encrypt integration for SSL certificates
- Admin UI on port 81
- HTTP (80) and HTTPS (443) proxy ports
- Automatic service enablement via systemd (npm.service, openresty.service)
- Logrotate configuration for log management
- template-update tool for in-container updates

### Notes

- This is a bare-metal installation. Official NPM only supports Docker.
- Based on community-scripts/ProxmoxVE installation method.

### Default Credentials

- Email: admin@example.com
- Password: changeme

[Unreleased]: https://github.com/deroy2112/proxmox-lxc-templates/compare/v2.13.5-1-nginx-proxy-manager...HEAD
[2.13.5-1]: https://github.com/deroy2112/proxmox-lxc-templates/releases/tag/v2.13.5-1-nginx-proxy-manager
