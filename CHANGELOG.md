# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-04-16

Complete rewrite as a .NET 10 global CLI tool (`sem`). The PowerShell module is retired.

### Added
- .NET 10 global tool — install with `dotnet tool install -g SecretsExpirationMonitor`
- `sem monitor` — check expiring secrets across all configured tenants
- `sem tenant add/remove/list` — manage tenants
- `sem config show/set` — view and update configuration
- Spectre.Console color-coded table output (cyan → yellow → orange → red urgency gradient)
- `--detailed` flag for per-tenant expired/critical/warning/info summary
- `--threshold` per-run override
- `-t/--tenant` flag to target a single tenant
- MSAL device code authentication with local token cache — silent on repeat runs
- Atomic config writes (write-then-move) to prevent corruption on crash
- Ctrl+C cancellation support during Graph API paging
- Validation on all user inputs (GUID format, positive threshold)
- Full NuGet package metadata (license, readme, project URL, source link)
- MSTest + Shouldly test suite covering `FilterSecrets`, `GetColor`, and `ConfigService`
- GitHub Actions release workflow: bumps `<Version>` in `.csproj`, builds, tests, packs, publishes to NuGet, and creates a GitHub release with the `.nupkg` attached
- Renovate Bot configured with weekly schedule, automerge for minor/patch NuGet updates

### Changed
- Secret filtering logic: secrets with no expiry date are now treated as permanently valid (suppress expiring secrets with the same name)
- Version is now sourced exclusively from `<Version>` in the `.csproj` — no separate `VERSION` file or module manifest

### Removed
- PowerShell module (`SecretsExpirationMonitor/`)
- Legacy standalone scripts (`Get-AppRegistrationSecrets.ps1`, `Start-Monitor.ps1`, `Test-AppRegistrationSecrets.ps1`)
- `Install.ps1` / `Uninstall.ps1`
- `Test-Module.ps1`
- `VERSION` file
- Auto-update feature (replaced by `dotnet tool update -g SecretsExpirationMonitor`)

## [1.1.1] - 2026-03-01

### Added
- GitHub Actions release workflow

## [1.0.0] - 2026-02-09

### Added
- Initial release as a PowerShell module

[Unreleased]: https://github.com/basmulder03/secrets-expiration-monitor/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/basmulder03/secrets-expiration-monitor/compare/v1.1.1...v2.0.0
[1.1.1]: https://github.com/basmulder03/secrets-expiration-monitor/compare/v1.0.0...v1.1.1
[1.0.0]: https://github.com/basmulder03/secrets-expiration-monitor/releases/tag/v1.0.0
