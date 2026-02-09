# Secrets Expiration Monitor

An installable, auto-updatable PowerShell CLI tool that uses the Microsoft Graph API to monitor Azure AD App Registration secrets expiration across multiple tenants.

> 📖 **New to this tool?** Check out the [Quick Start Guide](QUICKSTART.md) for a step-by-step walkthrough!

## Features

- 🚀 **Installable CLI Tool**: Install once, use anywhere in your PowerShell sessions
- 🔄 **Auto-Update**: Automatically checks for and installs updates from GitHub
- 🏢 **Multi-Tenant Support**: Monitor multiple Azure AD tenants simultaneously
- 💾 **Persistent Configuration**: Tenant settings are saved between sessions
- 🔍 Retrieves all app registrations from your Azure AD tenants
- ⏰ Identifies secrets that will expire soon (configurable threshold per tenant)
- 🎨 Color-coded output with gradient showing expiration urgency:
  - 🟢 **Green**: Valid secrets with more than 75% of threshold remaining
  - 🔵 **Cyan**: Secrets with 50-75% of threshold remaining
  - 🟡 **Yellow**: Warning - secrets with 25-50% of threshold remaining
  - 🔴 **Red**: Critical - secrets with less than 25% of threshold remaining or already expired
- 📊 Smart filtering: If a new secret with the same name exists that won't expire within the threshold, only shows the new one
- 📋 Compact table output with truncated fields and date-only columns (sorted by expiration date)

## Prerequisites

- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Microsoft.Graph PowerShell modules (automatically installed by the module):
  - `Microsoft.Graph.Applications`
  - `Microsoft.Graph.Authentication`
- Appropriate permissions to read application registrations in your Azure AD tenant(s)

## Permissions Required

The module requires the following Microsoft Graph API permission:
- **Application.Read.All**: Allows reading all applications and service principals

## Installation

### Option 1: Local Installation (Recommended)

1. Clone this repository:
   ```powershell
   git clone https://github.com/basmulder03/secrets-expiration-monitor.git
   cd secrets-expiration-monitor
   ```

2. Run the installation script:
   ```powershell
   .\Install.ps1
   ```

### Option 2: Direct Web Installation

Run this command to download and install directly:
```powershell
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/basmulder03/secrets-expiration-monitor/main/Install.ps1").Content
```

### Verify Installation

```powershell
Get-Module -ListAvailable SecretsExpirationMonitor
Import-Module SecretsExpirationMonitor
Get-Command -Module SecretsExpirationMonitor
```


## Quick Start

### 1. Add Your First Tenant

```powershell
Add-MonitorTenant -TenantId "your-tenant-id-here" -Name "Production" -DaysThreshold 90
```

### 2. Monitor All Configured Tenants

```powershell
Invoke-SecretsMonitor -All
```

Or use the alias:
```powershell
Monitor-Secrets -All
```

### 3. Monitor a Specific Tenant

```powershell
Invoke-SecretsMonitor -TenantName "Production"
```

## Usage

### Available Commands

| Command | Description |
|---------|-------------|
| `Invoke-SecretsMonitor` | Run the secrets expiration monitor |
| `Add-MonitorTenant` | Add a tenant to the configuration |
| `Remove-MonitorTenant` | Remove a tenant from the configuration |
| `Get-MonitorTenants` | List all configured tenants |
| `Get-MonitorConfig` | View global configuration |
| `Set-MonitorConfig` | Update global configuration |
| `Update-SecretsMonitor` | Check for and install updates |

### Managing Tenants

#### Add a Tenant

```powershell
# Add with default threshold (90 days)
Add-MonitorTenant -TenantId "12345678-1234-1234-1234-123456789abc" -Name "Production"

# Add with custom threshold
Add-MonitorTenant -TenantId "87654321-4321-4321-4321-cba987654321" -Name "Development" -DaysThreshold 30
```

#### List Tenants

```powershell
Get-MonitorTenants
```

#### Remove a Tenant

```powershell
# By name
Remove-MonitorTenant -Name "Development"

# By ID
Remove-MonitorTenant -TenantId "12345678-1234-1234-1234-123456789abc"
```

### Running the Monitor

#### Monitor All Tenants

```powershell
Invoke-SecretsMonitor -All
```

#### Monitor Specific Tenant by Name

```powershell
Invoke-SecretsMonitor -TenantName "Production"
```

#### Monitor Specific Tenant by ID

```powershell
Invoke-SecretsMonitor -TenantId "12345678-1234-1234-1234-123456789abc"
```

#### Override Threshold for a Single Run

```powershell
Invoke-SecretsMonitor -TenantName "Production" -DaysThreshold 30
```

### Configuration Management

#### View Configuration

```powershell
Get-MonitorConfig
```

#### Update Default Threshold

```powershell
Set-MonitorConfig -DefaultDaysThreshold 60
```

#### Disable Auto-Update

```powershell
Set-MonitorConfig -AutoUpdate $false
```

### Updates

#### Manual Update Check

```powershell
Update-SecretsMonitor
```

#### Force Update Check

```powershell
Update-SecretsMonitor -Force
```

The module automatically checks for updates every 7 days when loaded (if auto-update is enabled).

## Configuration

Configuration is automatically saved in a platform-specific location:
- **Windows**: `%APPDATA%\SecretsExpirationMonitor\config.json`
- **macOS**: `~/Library/Application Support/SecretsExpirationMonitor/config.json`
- **Linux**: `~/.config/SecretsExpirationMonitor/config.json`

The configuration includes:
- List of monitored tenants with their settings
- Default days threshold
- Auto-update preferences
- Last update check timestamp

## Parameters

### Invoke-SecretsMonitor

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `TenantName` | String | No | - | Monitor a specific tenant by name |
| `TenantId` | String | No | - | Monitor a specific tenant by ID |
| `DaysThreshold` | Integer | No | Tenant setting | Override the days threshold for this run |
| `All` | Switch | No | - | Monitor all configured tenants |

### Add-MonitorTenant

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `TenantId` | String | Yes | - | The Azure AD tenant ID |
| `Name` | String | Yes | - | A friendly name for the tenant |
| `DaysThreshold` | Integer | No | Global default | Number of days to check for expiring secrets |

## Output

The module provides:

1. **Connection Status**: Shows successful connection to Microsoft Graph and tenant information
2. **Progress Information**: Displays the number of app registrations found per tenant
3. **Detailed Secret Information**: For each secret requiring attention:
   - Tenant Name (when monitoring multiple tenants)
   - App Name
   - App ID
   - Secret Name
   - Key ID
   - Start Date
   - End Date
   - Days Remaining (color-coded)
   - Status (Expired/Expiring/Valid)
4. **Per-Tenant Summary**: Statistics for each tenant
5. **Overall Summary**: Aggregated statistics when monitoring multiple tenants

## Example Output

```
Secrets Expiration Monitor
================================================================================
Monitoring 2 tenant(s)
================================================================================

[Production] Connecting to Microsoft Graph...
[Production] Connected to tenant: 12345678-1234-1234-1234-123456789abc
[Production] Checking for secrets expiring within 90 days...
[Production] Retrieving app registrations...
[Production] Found 45 app registrations

[Production] Found 2 secret(s) requiring attention:

================================================================================
App Name: MyWebApp
App ID: aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
Secret Name: Production Secret
Key ID: 11111111-2222-3333-4444-555555555555
Start Date: 2025-01-15 10:30:00
End Date: 2026-02-28 10:30:00
Days Remaining: 19
Status: Expiring
================================================================================

[Production] Summary:
================================================================================
Expired: 0
Critical (< 22 days): 1
Warning (< 45 days): 0
Info (< 90 days): 1
================================================================================

[Production] Disconnected from Microsoft Graph

================================================================================
Overall Summary Across All Tenants
================================================================================
Total Secrets Requiring Attention: 3
  Expired: 0
  Expiring: 2
  Valid (but flagged): 1
================================================================================
```


## Uninstallation

To uninstall the module:

```powershell
.\Uninstall.ps1
```

To uninstall and remove all configuration:

```powershell
.\Uninstall.ps1 -RemoveConfig
```

## How It Works

1. **Module Loading**: When imported, the module loads your saved configuration and optionally checks for updates
2. **Tenant Management**: Add, remove, or list tenants with persistent configuration
3. **Connection**: For each tenant, establishes a connection to Microsoft Graph API using interactive authentication with `Application.Read.All` scope
4. **Retrieval**: Fetches all app registrations from the specified tenant(s)
5. **Analysis**: For each app registration with secrets:
   - Groups secrets by display name
   - Checks if there's a newer secret with the same name that won't expire within the threshold
   - If a valid replacement exists, shows only the new secret
   - If no replacement exists, shows all expiring secrets
6. **Display**: Outputs results in a formatted, color-coded display sorted by days remaining
7. **Summary**: Provides per-tenant and overall statistics

## Smart Filtering Logic

The module implements intelligent filtering to avoid alert fatigue:

- When multiple secrets share the same display name, the module checks if any of them is valid (won't expire within the threshold period)
- If a valid replacement secret exists, only that secret is shown
- If no valid replacement exists, all expiring secrets with that name are shown
- This ensures you're only alerted about secrets that truly need attention

## Auto-Update

The module includes built-in auto-update functionality:

- Automatically checks GitHub for new releases
- Checks every 7 days when the module is loaded (configurable)
- Can be manually triggered with `Update-SecretsMonitor`
- Downloads and installs updates with user confirmation
- Can be disabled with `Set-MonitorConfig -AutoUpdate $false`

## Security Considerations

- The module uses interactive authentication and does not store credentials
- Requires appropriate Azure AD permissions to read app registrations
- Run with least privilege - only the `Application.Read.All` scope is needed
- Configuration files are stored in user-specific directories
- Disconnect from Microsoft Graph is automatic at the end of each run


## Troubleshooting

### Module Installation Fails
If automatic module installation fails, manually install the required modules:
```powershell
Install-Module -Name Microsoft.Graph.Applications -Scope CurrentUser -Force
Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Force
```

### Module Not Found After Installation
Restart your PowerShell session or manually import:
```powershell
Import-Module SecretsExpirationMonitor -Force
```

### Authentication Issues
- Ensure you have appropriate permissions in your Azure AD tenant
- Verify your account has at least Application Reader role or equivalent
- Try disconnecting and reconnecting: `Disconnect-MgGraph`

### No Secrets Found
- Verify the app registrations actually have password credentials (client secrets)
- Check if the secrets are within your specified threshold period
- Ensure the module has proper permissions to read application data

### Configuration Issues
To reset configuration:
```powershell
# View config location
Get-MonitorConfig

# Manually delete the config file and restart PowerShell
```

### Update Failures
If auto-update fails:
1. Download the latest release manually from GitHub
2. Run `.\Uninstall.ps1`
3. Run `.\Install.ps1` from the new version

## Legacy Scripts

The repository includes legacy standalone scripts for backwards compatibility:
- `Get-AppRegistrationSecrets.ps1` - Original standalone script
- `Start-Monitor.ps1` - Wrapper script with config file support
- `Test-AppRegistrationSecrets.ps1` - Test suite

These scripts are maintained but the module approach is recommended for new installations.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the MIT License.

## Author

Created for monitoring Azure AD App Registration secrets expiration to help maintain security compliance and prevent service interruptions.
