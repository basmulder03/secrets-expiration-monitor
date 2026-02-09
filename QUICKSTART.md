# Quick Start Guide

This guide will help you get up and running with Secrets Expiration Monitor in minutes.

## Installation

### Step 1: Install the Module

```powershell
# Clone the repository
git clone https://github.com/basmulder03/secrets-expiration-monitor.git
cd secrets-expiration-monitor

# Run the installer
.\Install.ps1
```

The installer will:
- Copy the module to your PowerShell modules directory
- Import the module automatically
- Display available commands

### Step 2: Verify Installation

```powershell
Get-Command -Module SecretsExpirationMonitor
```

You should see:
- `Invoke-SecretsMonitor` (main command)
- `Add-MonitorTenant`
- `Remove-MonitorTenant`
- `Get-MonitorTenants`
- `Get-MonitorConfig`
- `Set-MonitorConfig`
- `Update-SecretsMonitor`
- Plus aliases: `Monitor-Secrets`, `Check-Secrets`

## Configuration

### Step 3: Add Your First Tenant

```powershell
Add-MonitorTenant -TenantId "your-tenant-id" -Name "Production" -DaysThreshold 90
```

- **TenantId**: Your Azure AD tenant ID (found in Azure Portal)
- **Name**: A friendly name to identify this tenant
- **DaysThreshold**: How many days ahead to check for expiring secrets (default: 90)

### Step 4: Verify Configuration

```powershell
Get-MonitorTenants
```

This shows all configured tenants.

## Running the Monitor

### Monitor All Tenants

```powershell
Invoke-SecretsMonitor -All
```

Or use the shorter alias:

```powershell
Monitor-Secrets -All
```

### Monitor a Specific Tenant

```powershell
Invoke-SecretsMonitor -TenantName "Production"
```

### First Run Authentication

The first time you run the monitor, you'll be prompted to authenticate with Microsoft Graph:

1. A browser window will open
2. Sign in with your Azure AD account
3. Consent to the `Application.Read.All` permission
4. Return to PowerShell to see the results

## Understanding the Output

The monitor will show:

### Connection Info
```
[Production] Connecting to Microsoft Graph...
[Production] Connected to tenant: 12345678-1234-1234-1234-123456789abc
[Production] Checking for secrets expiring within 90 days...
```

### Secret Details
Color-coded by urgency:
- 🟢 **Green**: >75% of threshold remaining
- 🔵 **Cyan**: 50-75% remaining
- 🟡 **Yellow**: 25-50% remaining
- 🔴 **Red**: <25% remaining or expired

```
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
```

### Summary Statistics
```
[Production] Summary:
================================================================================
Expired: 0
Critical (< 22 days): 1
Warning (< 45 days): 0
Info (< 90 days): 1
================================================================================
```

## Managing Multiple Tenants

### Add Another Tenant

```powershell
Add-MonitorTenant -TenantId "tenant-id-2" -Name "Development" -DaysThreshold 30
```

### List All Tenants

```powershell
Get-MonitorTenants
```

### Remove a Tenant

```powershell
Remove-MonitorTenant -Name "Development"
```

### Monitor All Tenants

```powershell
Monitor-Secrets -All
```

## Configuration Options

### View Current Config

```powershell
Get-MonitorConfig
```

### Change Default Threshold

```powershell
Set-MonitorConfig -DefaultDaysThreshold 60
```

This applies to new tenants only. Existing tenants keep their configured threshold.

### Disable Auto-Update

```powershell
Set-MonitorConfig -AutoUpdate $false
```

## Updating

### Manual Update Check

```powershell
Update-SecretsMonitor
```

### Automatic Updates

By default, the module checks for updates every 7 days when loaded. You'll be prompted to update if a new version is available.

## Common Scenarios

### Scenario 1: Single Tenant Organization

```powershell
# Setup
Add-MonitorTenant -TenantId "your-tenant-id" -Name "MyOrg" -DaysThreshold 90

# Run weekly
Monitor-Secrets -TenantName "MyOrg"
```

### Scenario 2: Multiple Environments

```powershell
# Setup
Add-MonitorTenant -TenantId "prod-tenant-id" -Name "Production" -DaysThreshold 90
Add-MonitorTenant -TenantId "dev-tenant-id" -Name "Development" -DaysThreshold 30
Add-MonitorTenant -TenantId "test-tenant-id" -Name "Testing" -DaysThreshold 45

# Run monthly across all
Monitor-Secrets -All
```

### Scenario 3: MSP with Multiple Clients

```powershell
# Setup
Add-MonitorTenant -TenantId "client1-id" -Name "Client-Contoso" -DaysThreshold 60
Add-MonitorTenant -TenantId "client2-id" -Name "Client-Fabrikam" -DaysThreshold 60
Add-MonitorTenant -TenantId "client3-id" -Name "Client-AdventureWorks" -DaysThreshold 60

# Run weekly across all clients
Monitor-Secrets -All
```

## Scheduled Execution

### Windows Task Scheduler

Create a scheduled task that runs:

```powershell
powershell.exe -Command "Import-Module SecretsExpirationMonitor; Monitor-Secrets -All"
```

### Linux/macOS Cron

Add to crontab:

```bash
# Run every Monday at 9 AM
0 9 * * 1 /usr/bin/pwsh -Command "Import-Module SecretsExpirationMonitor; Monitor-Secrets -All"
```

## Troubleshooting

### Module Not Found

```powershell
# Manually import
Import-Module SecretsExpirationMonitor -Force
```

### Permission Denied

Ensure you have:
- Application Reader role in Azure AD, or
- Global Reader role, or
- Custom role with Application.Read.All permission

### No Secrets Found

Check:
1. Apps have password credentials (not just certificates)
2. Secrets are within your threshold period
3. Your account has proper permissions

## Next Steps

- Check the [README.md](README.md) for complete documentation
- Review the example output to understand what to expect
- Set up scheduled execution for automated monitoring
- Configure per-tenant thresholds based on your security policy

## Getting Help

```powershell
# Get help for any command
Get-Help Invoke-SecretsMonitor -Detailed
Get-Help Add-MonitorTenant -Examples
Get-Help Get-MonitorConfig -Full
```

## Uninstalling

If you need to uninstall:

```powershell
# Keep configuration
.\Uninstall.ps1

# Remove everything including configuration
.\Uninstall.ps1 -RemoveConfig
```
