# Secrets Expiration Monitor

A PowerShell application that uses the Microsoft Graph API to monitor Azure AD App Registration secrets expiration for a configured tenant.

## Features

- 🔍 Retrieves all app registrations from your Azure AD tenant
- ⏰ Identifies secrets that will expire soon (configurable threshold)
- 🎨 Color-coded output with gradient showing expiration urgency:
  - 🟢 **Green**: Valid secrets with more than 75% of threshold remaining
  - 🔵 **Cyan**: Secrets with 50-75% of threshold remaining
  - 🟡 **Yellow**: Warning - secrets with 25-50% of threshold remaining
  - 🔴 **Red**: Critical - secrets with less than 25% of threshold remaining or already expired
- 📊 Smart filtering: If a new secret with the same name exists that won't expire within the threshold, only shows the new one
- 📋 Formatted output with detailed information about each secret

## Prerequisites

- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Microsoft.Graph PowerShell modules (automatically installed if missing):
  - `Microsoft.Graph.Applications`
  - `Microsoft.Graph.Authentication`
- Appropriate permissions to read application registrations in your Azure AD tenant

## Permissions Required

The script requires the following Microsoft Graph API permission:
- **Application.Read.All**: Allows reading all applications and service principals

## Installation

1. Clone this repository:
   ```powershell
   git clone https://github.com/basmulder03/secrets-expiration-monitor.git
   cd secrets-expiration-monitor
   ```

2. The required Microsoft Graph modules will be automatically installed when you run the script for the first time.

## Usage

### Basic Usage

Run the script with default settings (90-day threshold):
```powershell
.\Get-AppRegistrationSecrets.ps1
```

### Custom Expiration Threshold

Check for secrets expiring within 60 days:
```powershell
.\Get-AppRegistrationSecrets.ps1 -DaysThreshold 60
```

### Specify Tenant ID

Connect to a specific tenant:
```powershell
.\Get-AppRegistrationSecrets.ps1 -TenantId "your-tenant-id-here" -DaysThreshold 30
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `TenantId` | String | No | Current tenant | The Azure AD tenant ID to connect to |
| `DaysThreshold` | Integer | No | 90 | Number of days to check for expiring secrets |

## Output

The script provides:

1. **Connection Status**: Shows successful connection to Microsoft Graph and tenant information
2. **Progress Information**: Displays the number of app registrations found
3. **Detailed Secret Information**: For each secret requiring attention:
   - App Name
   - App ID
   - Secret Name
   - Key ID
   - Start Date
   - End Date
   - Days Remaining (color-coded)
   - Status (Expired/Expiring/Valid)
4. **Summary Statistics**: 
   - Count of expired secrets
   - Count of critical secrets (< 25% of threshold)
   - Count of warning secrets (< 50% of threshold)
   - Count of info secrets (< 100% of threshold)

## How It Works

1. **Connection**: Establishes a connection to Microsoft Graph API using interactive authentication with `Application.Read.All` scope
2. **Retrieval**: Fetches all app registrations from the specified tenant
3. **Analysis**: For each app registration with secrets:
   - Groups secrets by display name
   - Checks if there's a newer secret with the same name that won't expire within the threshold
   - If a valid replacement exists, shows only the new secret
   - If no replacement exists, shows all expiring secrets
4. **Display**: Outputs results in a formatted, color-coded display sorted by days remaining

## Smart Filtering Logic

The script implements intelligent filtering to avoid alert fatigue:

- When multiple secrets share the same display name, the script checks if any of them is valid (won't expire within the threshold period)
- If a valid replacement secret exists, only that secret is shown
- If no valid replacement exists, all expiring secrets with that name are shown
- This ensures you're only alerted about secrets that truly need attention

## Example Output

```
Connecting to Microsoft Graph...
Successfully connected to Microsoft Graph.
Tenant: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Checking for secrets expiring within 90 days...

Retrieving app registrations...
Found 45 app registrations.

Found 3 secret(s) requiring attention:

================================================================================
App Name: MyWebApp
App ID: 12345678-1234-1234-1234-123456789abc
Secret Name: Production Secret
Key ID: abcd1234-5678-90ab-cdef-1234567890ab
Start Date: 2025-01-15 10:30:00
End Date: 2026-02-28 10:30:00
Days Remaining: 19
Status: Expiring
================================================================================

Summary:
================================================================================
Expired: 0
Critical (< 22 days): 1
Warning (< 45 days): 0
Info (< 90 days): 2
================================================================================

Disconnecting from Microsoft Graph...
Disconnected successfully.
```

## Security Considerations

- The script uses interactive authentication and does not store credentials
- Requires appropriate Azure AD permissions to read app registrations
- Run with least privilege - only the `Application.Read.All` scope is needed
- Disconnect from Microsoft Graph is automatic at the end of execution

## Troubleshooting

### Module Installation Fails
If automatic module installation fails, manually install the required modules:
```powershell
Install-Module -Name Microsoft.Graph.Applications -Scope CurrentUser -Force
Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Force
```

### Authentication Issues
- Ensure you have appropriate permissions in your Azure AD tenant
- Verify your account has at least Application Reader role or equivalent
- Try disconnecting and reconnecting: `Disconnect-MgGraph`

### No Secrets Found
- Verify the app registrations actually have password credentials (client secrets)
- Check if the secrets are within your specified threshold period
- Ensure the script has proper permissions to read application data

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the MIT License.

## Author

Created for monitoring Azure AD App Registration secrets expiration to help maintain security compliance and prevent service interruptions.