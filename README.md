# Secrets Expiration Monitor

A .NET global tool (`sem`) that uses the Microsoft Graph API to monitor Azure AD App Registration client secrets for expiration across multiple tenants.

## Requirements

- [.NET 9 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)
- An Azure AD account with `Application.Read.All` permission

## Installation

```bash
dotnet tool install -g SecretsExpirationMonitor
```

Or build and install locally from the `src/` folder:

```bash
dotnet pack src/
dotnet tool install -g --add-source src/nupkg SecretsExpirationMonitor
```

## Quick Start

```bash
# Add a tenant
sem tenant add xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx "Contoso"

# Run the monitor (browser/device-code auth prompt on first run)
sem monitor

# Show detailed per-tenant summary
sem monitor --detailed
```

## Command Reference

### `sem monitor`

Checks all configured tenants for secrets expiring within the threshold.

```
OPTIONS:
  -t, --tenant <NAME_OR_ID>   Only monitor this tenant
  --threshold <DAYS>          Override the days threshold for this run
  -d, --detailed              Show per-tenant summary after the table
```

### `sem tenant`

| Command | Description |
|---|---|
| `sem tenant add <ID> <NAME>` | Add a tenant to monitor |
| `sem tenant remove <NAME_OR_ID>` | Remove a tenant by name or ID |
| `sem tenant list` | List all configured tenants |

### `sem config`

| Command | Description |
|---|---|
| `sem config show` | Display current configuration |
| `sem config set --threshold <DAYS>` | Set the expiry alert threshold (default: 90 days) |

## How It Works

1. On first run per tenant, a device code or browser authentication prompt is shown via MSAL.
2. The token is cached locally (in `%APPDATA%\SecretsExpirationMonitor\msal_cache\`) so subsequent runs are silent.
3. All App Registrations are fetched via Microsoft Graph (`Application.Read.All`).
4. **Smart filtering**: if a secret name has a valid (non-expiring) counterpart with the same display name, the expiring one is suppressed. Only actionable secrets are shown.
5. Results are displayed in a color-coded table: cyan → yellow → orange → red as urgency increases.

## Color Legend

| Color | Meaning |
|---|---|
| Cyan | > 50% of threshold remaining |
| Yellow | 25–50% remaining |
| Orange | 10–25% remaining |
| Red | < 10% remaining or already expired |

## Configuration

Config is stored at `%APPDATA%\SecretsExpirationMonitor\config.json` on Windows, or the equivalent `~/.config/SecretsExpirationMonitor/config.json` on Linux/macOS.

## Project Structure

```
src/
├── Commands/
│   ├── MonitorCommand.cs
│   ├── TenantAddCommand.cs
│   ├── TenantRemoveCommand.cs
│   ├── TenantListCommand.cs
│   ├── ConfigShowCommand.cs
│   └── ConfigSetCommand.cs
├── Models/
│   ├── AppConfig.cs
│   └── SecretInfo.cs
├── Services/
│   ├── ConfigService.cs
│   └── GraphService.cs
└── Program.cs
```
