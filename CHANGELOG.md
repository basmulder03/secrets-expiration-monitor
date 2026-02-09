# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-09

### Added
- Initial release of Secrets Expiration Monitor
- PowerShell module with installable CLI tool
- Multi-tenant support with persistent configuration
- Auto-update functionality from GitHub releases
- Microsoft Graph API integration with Application.Read.All scope
- Smart filtering logic for duplicate secret names
- Color-coded output with expiration urgency gradient
- Seven main commands:
  - `Invoke-SecretsMonitor` - Monitor secrets expiration
  - `Add-MonitorTenant` - Add tenant to configuration
  - `Remove-MonitorTenant` - Remove tenant from configuration
  - `Get-MonitorTenants` - List all configured tenants
  - `Get-MonitorConfig` - View global configuration
  - `Set-MonitorConfig` - Update global configuration
  - `Update-SecretsMonitor` - Check for and install updates
- Command aliases: `Monitor-Secrets`, `Check-Secrets`
- Cross-platform support (Windows, macOS, Linux)
- Installation and uninstallation scripts
- Comprehensive test suite (10 module tests, 10 function tests)
- Legacy standalone scripts for backwards compatibility
- Complete documentation:
  - README.md with full documentation
  - QUICKSTART.md for new users
  - Inline help for all commands
  - Example configuration file

### Features
- Per-tenant expiration thresholds
- Persistent configuration across sessions
- Automatic module load on import
- Configurable auto-update checks (every 7 days by default)
- Overall summary when monitoring multiple tenants
- Platform-specific configuration storage
- Graceful error handling and informative messages
- No stored credentials (interactive authentication only)

### Security
- Read-only access with Application.Read.All scope
- No credential storage
- Automatic disconnect from Microsoft Graph
- User-specific configuration directories
- Input validation and error handling

[1.0.0]: https://github.com/basmulder03/secrets-expiration-monitor/releases/tag/v1.0.0
